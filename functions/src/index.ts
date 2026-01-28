import {onRequest} from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import {getGeminiModel} from "./gemini";
import {executeTool} from "./tools/registry";
import {authenticateRequest} from "./middleware/auth";
import {ChatRequest} from "./types";

admin.initializeApp();

/**
 * POST /chat — HTTP Cloud Function for the RallyBot chatbot.
 *
 * Flow:
 * 1. Verify Firebase Auth ID token
 * 2. Load user profile from Firestore
 * 3. Build Gemini chat with system instructions + user context
 * 4. Send user message and handle function calling loop
 * 5. Return Gemini's text response (+ created event ID if applicable)
 */
export const chat = onRequest(
  {
    cors: true,
    secrets: ["GEMINI_API_KEY"],
    timeoutSeconds: 60,
    memory: "256MiB",
  },
  async (req, res) => {
    // Only accept POST
    if (req.method !== "POST") {
      res.status(405).json({error: "Method not allowed. Use POST."});
      return;
    }

    try {
      // 1. Authenticate
      const user = await authenticateRequest(req);

      // 2. Parse request body
      const {message, history} = req.body as ChatRequest;

      if (!message || typeof message !== "string" || message.trim().length === 0) {
        res.status(400).json({error: "Message is required."});
        return;
      }

      // 3. Get Gemini API key from secrets
      const apiKey = process.env.GEMINI_API_KEY;
      if (!apiKey) {
        res.status(500).json({error: "Gemini API key not configured."});
        return;
      }

      // 4. Build Gemini chat session with user context
      const model = getGeminiModel(apiKey);
      const chatSession = model.startChat({
        history: [
          {
            role: "user",
            parts: [
              {
                text:
                  `[CONTEXT] Current user: ${user.displayName} ` +
                  `(uid: ${user.uid}, rating: ${user.rating}). ` +
                  `Current time: ${new Date().toISOString()}.`,
              },
            ],
          },
          {
            role: "model",
            parts: [
              {
                text:
                  `Hello ${user.displayName}! I'm RallyBot. ` +
                  `How can I help you with badminton events today?`,
              },
            ],
          },
          ...(history || []),
        ],
      });

      // 5. Send message and handle function calling loop
      let response = await chatSession.sendMessage(message);
      let result = response.response;
      let createdEventId: string | null = null;

      // Loop to handle function calls from Gemini
      let iterations = 0;
      const maxIterations = 5; // Safety limit

      while (
        iterations < maxIterations &&
        result.candidates?.[0]?.content?.parts?.some(
          (p: any) => p.functionCall
        )
      ) {
        iterations++;

        const functionCallPart = result.candidates![0].content.parts.find(
          (p: any) => p.functionCall
        ) as any;

        const functionCall = functionCallPart.functionCall;

        // Execute the tool
        const toolResult = await executeTool(
          functionCall.name,
          functionCall.args,
          user
        );

        // Track created event ID
        if (toolResult.success && toolResult.event_id) {
          createdEventId = toolResult.event_id;
        }

        // Send tool result back to Gemini for natural language response
        response = await chatSession.sendMessage([
          {
            functionResponse: {
              name: functionCall.name,
              response: toolResult as any,
            },
          },
        ] as any);
        result = response.response;
      }

      // 6. Extract text response
      const textResponse =
        result.candidates?.[0]?.content?.parts
          ?.filter((p: any) => p.text)
          .map((p: any) => p.text)
          .join("") || "Sorry, I couldn't process that request.";

      res.json({
        reply: textResponse,
        created_event_id: createdEventId,
      });
    } catch (err: any) {
      const statusCode = err.statusCode || 500;
      const message = err.message || "Internal server error";
      res.status(statusCode).json({error: message});
    }
  }
);
