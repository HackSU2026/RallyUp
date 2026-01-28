# MCP Server + Firebase + Gemini: In-App Chatbot Event Creation Plan

## Overview

This plan describes how to implement an MCP (Model Context Protocol) server backed by Firebase Cloud Functions, integrated with Google Gemini, to power an in-app chatbot that can create badminton events through natural language conversation.

**User story:** A user opens the chatbot, types "Create a doubles practice session at the UW rec center tomorrow at 6pm", and Gemini extracts the structured event parameters, calls the `create_event` MCP tool, writes to Firestore, and confirms back to the user.

---

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                     Flutter App (Client)                     │
│                                                              │
│  ┌──────────────┐    ┌──────────────────────────────────┐   │
│  │ CreateEvent   │    │  GeminiChatScreen (NEW)           │   │
│  │ Page (exists) │    │  - Chat UI with message bubbles   │   │
│  │               │    │  - Sends user text to backend      │   │
│  │               │    │  - Shows Gemini responses           │   │
│  │               │    │  - Displays created event cards     │   │
│  └──────────────┘    └──────────┬───────────────────────┘   │
│                                  │ HTTPS POST               │
└──────────────────────────────────┼──────────────────────────┘
                                   │
                                   ▼
┌──────────────────────────────────────────────────────────────┐
│              Firebase Cloud Functions (Backend)                │
│                                                               │
│  ┌────────────────────────────────────────────────────────┐  │
│  │  POST /chat  (HTTP Cloud Function)                     │  │
│  │                                                        │  │
│  │  1. Authenticate request (Firebase Auth ID token)      │  │
│  │  2. Load user profile from Firestore                   │  │
│  │  3. Build Gemini prompt with system instructions        │  │
│  │  4. Call Gemini API with function declarations          │  │
│  │  5. If Gemini returns function_call → execute tool      │  │
│  │  6. Return Gemini response + tool results to client     │  │
│  └───────┬─────────────────────────┬──────────────────────┘  │
│          │                         │                          │
│          ▼                         ▼                          │
│  ┌──────────────┐    ┌──────────────────────────────────┐    │
│  │ Gemini API   │    │ MCP Tool: create_event            │    │
│  │ (gemini-2.0  │    │ - Validates parameters             │    │
│  │  -flash)     │    │ - Enforces business rules          │    │
│  │              │    │ - Writes to Firestore events col   │    │
│  └──────────────┘    │ - Returns created event summary    │    │
│                      └──────────────────────────────────┘    │
│                                                               │
│                      ┌──────────────────────────────────┐    │
│                      │ Firestore                         │    │
│                      │ - users (read)                    │    │
│                      │ - events (read/write)             │    │
│                      │ - chat_sessions (read/write, NEW) │    │
│                      └──────────────────────────────────┘    │
└──────────────────────────────────────────────────────────────┘
```

---

## Phase 1: Firebase Cloud Functions Setup

### 1.1 Initialize Firebase Functions

Create a `functions/` directory at the project root with a Node.js/TypeScript Cloud Functions project.

**Files to create:**
```
RallyUp/
└── functions/
    ├── package.json
    ├── tsconfig.json
    ├── .eslintrc.js
    └── src/
        ├── index.ts              # Cloud Function entry point
        ├── gemini.ts             # Gemini API client wrapper
        ├── tools/
        │   ├── registry.ts       # MCP tool registry
        │   └── create_event.ts   # create_event tool implementation
        ├── middleware/
        │   └── auth.ts           # Firebase Auth token verification
        └── types/
            └── index.ts          # Shared TypeScript types
```

**Key dependencies (package.json):**
```json
{
  "dependencies": {
    "firebase-admin": "^12.0.0",
    "firebase-functions": "^5.0.0",
    "@google/generative-ai": "^0.21.0"
  }
}
```

### 1.2 Environment Configuration

Store the Gemini API key securely using Firebase Functions config or Secret Manager:

```bash
firebase functions:secrets:set GEMINI_API_KEY
```

---

## Phase 2: MCP Tool — `create_event`

### 2.1 Tool Schema (Gemini Function Declaration)

Define the tool so Gemini knows how to call it. This follows the Gemini function calling format which maps to MCP tool semantics:

```typescript
// functions/src/tools/create_event.ts

export const createEventDeclaration = {
  name: "create_event",
  description:
    "Creates a new badminton event (practice session or competition match) " +
    "in RallyUp. The authenticated user becomes the host and first participant. " +
    "Rating range is auto-calculated from the host's current rating (±200).",
  parameters: {
    type: "object",
    properties: {
      title: {
        type: "string",
        description:
          "Event title. If omitted or empty, defaults to 'Practice' or 'Competition' based on event_type.",
      },
      event_type: {
        type: "string",
        enum: ["practice", "match"],
        description:
          "Type of event. 'practice' = casual practice (up to 9999 participants). " +
          "'match' = competitive match (fixed headcount: 2 for singles, 4 for doubles).",
      },
      variant: {
        type: "string",
        enum: ["singles", "doubles"],
        description: "Badminton variant. 'singles' = 1v1. 'doubles' = 2v2.",
      },
      location: {
        type: "string",
        description:
          "Event location. Ideally a Google Maps URL, but a venue name or address is also accepted.",
      },
      start_at: {
        type: "string",
        description:
          "Event start time in ISO 8601 format (e.g. '2025-06-15T18:00:00'). " +
          "Must be in the future.",
      },
      end_at: {
        type: "string",
        description:
          "Event end time in ISO 8601 format. Must be after start_at.",
      },
    },
    required: ["event_type", "variant", "location", "start_at", "end_at"],
  },
};
```

### 2.2 Tool Execution Logic

```typescript
// functions/src/tools/create_event.ts

import * as admin from "firebase-admin";

interface CreateEventParams {
  title?: string;
  event_type: "practice" | "match";
  variant: "singles" | "doubles";
  location: string;
  start_at: string; // ISO 8601
  end_at: string; // ISO 8601
}

interface UserProfile {
  uid: string;
  email: string;
  displayName: string;
  rating: number;
}

export async function executeCreateEvent(
  params: CreateEventParams,
  user: UserProfile
): Promise<{ success: boolean; event_id?: string; summary?: string; error?: string }> {
  const db = admin.firestore();

  // 1. Parse and validate dates
  const startAt = new Date(params.start_at);
  const endAt = new Date(params.end_at);
  const now = new Date();

  if (isNaN(startAt.getTime()) || isNaN(endAt.getTime())) {
    return { success: false, error: "Invalid date format. Use ISO 8601." };
  }
  if (startAt <= now) {
    return { success: false, error: "Start time must be in the future." };
  }
  if (endAt <= startAt) {
    return { success: false, error: "End time must be after start time." };
  }

  // 2. Calculate business-rule fields
  const isCompetition = params.event_type === "match";
  const maxParticipants = isCompetition
    ? params.variant === "doubles" ? 4 : 2
    : 9999;

  const title = params.title?.trim() ||
    (isCompetition ? "Competition" : "Practice");

  const minRating = user.rating - 200;
  const maxRating = user.rating + 200;

  // 3. Write to Firestore
  const eventData = {
    title,
    eventType: params.event_type,
    hostId: user.uid,
    location: params.location,
    variant: params.variant,
    ratingRange: { min: minRating, max: maxRating },
    maxParticipants,
    participants: [user.uid],
    matches: null,
    status: "open",
    startAt: admin.firestore.Timestamp.fromDate(startAt),
    endAt: admin.firestore.Timestamp.fromDate(endAt),
    createdAt: admin.firestore.Timestamp.now(),
    updatedAt: admin.firestore.Timestamp.now(),
  };

  const docRef = await db.collection("events").add(eventData);

  return {
    success: true,
    event_id: docRef.id,
    summary:
      `Created "${title}" (${params.event_type}, ${params.variant}) ` +
      `at ${params.location}, from ${startAt.toLocaleString()} to ${endAt.toLocaleString()}. ` +
      `Rating range: ${minRating}–${maxRating}. Event ID: ${docRef.id}`,
  };
}
```

### 2.3 Business Rules Enforced Server-Side

These rules mirror the existing `CreateEventPage` logic and **must** be enforced on the backend to prevent chatbot bypass:

| Rule | Implementation |
|------|---------------|
| Competition headcount is fixed | `doubles → 4`, `singles → 2` (not user-configurable) |
| Rating range = host ±200 | Fetched from user's Firestore profile, not from user input |
| Start must be in the future | Server-side validation |
| End must be after start | Server-side validation |
| Host auto-joins as participant | `participants: [user.uid]` |
| Default title if blank | `"Practice"` or `"Competition"` based on type |
| Event status starts as open | Hardcoded to `"open"` |

---

## Phase 3: Gemini Integration

### 3.1 Gemini Client Setup

```typescript
// functions/src/gemini.ts

import { GoogleGenerativeAI, FunctionDeclarationSchemaType } from "@google/generative-ai";
import { createEventDeclaration } from "./tools/create_event";

const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY!);

export function getGeminiModel() {
  return genAI.getGenerativeModel({
    model: "gemini-2.0-flash",
    tools: [
      {
        functionDeclarations: [createEventDeclaration],
      },
    ],
    systemInstruction: SYSTEM_PROMPT,
  });
}
```

### 3.2 System Prompt

The system prompt gives Gemini context about RallyUp, the user, and how to use the tools:

```typescript
const SYSTEM_PROMPT = `
You are RallyBot, the AI assistant for RallyUp — a badminton event finder app.
You help users create and manage badminton events through natural conversation.

CAPABILITIES:
- Create new badminton events (practice sessions or competitive matches)
- Answer questions about RallyUp features

CONTEXT PROVIDED WITH EACH REQUEST:
- The authenticated user's display name, rating, and uid
- The current date/time

EVENT CREATION RULES:
- Events have two types: "practice" (casual, up to 9999 players) and "match" (competitive, fixed headcount)
- Events have two variants: "singles" (1v1) and "doubles" (2v2)
- Competition headcount is automatic: 2 for singles, 4 for doubles
- Rating range is auto-set to the host's rating ±200 (do NOT ask the user for this)
- Location should be specific (venue name, address, or Google Maps link)
- Start time must be in the future; end time must be after start time

CONVERSATION GUIDELINES:
- If the user's message is ambiguous, ask clarifying questions before calling create_event
- Always confirm the event details before creating (show a summary and ask "Should I create this?")
- After creating, share the event summary and event ID
- Be concise and friendly
- If the user asks about something unrelated to RallyUp, politely redirect

REQUIRED FIELDS (you must gather these before creating):
1. event_type (practice or match) — ask if unclear
2. variant (singles or doubles) — ask if unclear
3. location — always ask if not provided
4. start_at and end_at — always ask if not provided; help parse natural language dates
   like "tomorrow at 6pm" or "next Saturday 2-4pm"

OPTIONAL FIELDS:
- title — auto-generated if not provided
`;
```

### 3.3 Chat Endpoint with Function Calling Loop

```typescript
// functions/src/index.ts

import { onRequest } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import { getGeminiModel } from "./gemini";
import { executeCreateEvent } from "./tools/create_event";

admin.initializeApp();

export const chat = onRequest(
  { cors: true, secrets: ["GEMINI_API_KEY"] },
  async (req, res) => {
    // 1. Verify Firebase Auth token
    const idToken = req.headers.authorization?.split("Bearer ")[1];
    if (!idToken) {
      res.status(401).json({ error: "Missing auth token" });
      return;
    }

    let decodedToken;
    try {
      decodedToken = await admin.auth().verifyIdToken(idToken);
    } catch {
      res.status(401).json({ error: "Invalid auth token" });
      return;
    }

    // 2. Load user profile
    const userDoc = await admin
      .firestore()
      .collection("users")
      .doc(decodedToken.uid)
      .get();
    if (!userDoc.exists) {
      res.status(404).json({ error: "User profile not found" });
      return;
    }
    const userProfile = {
      uid: decodedToken.uid,
      ...userDoc.data(),
    };

    // 3. Extract request body
    const { message, history } = req.body as {
      message: string;
      history?: Array<{ role: string; parts: Array<{ text: string }> }>;
    };

    // 4. Build Gemini chat with context
    const model = getGeminiModel();
    const chat = model.startChat({
      history: [
        {
          role: "user",
          parts: [
            {
              text:
                `[CONTEXT] Current user: ${userProfile.displayName} ` +
                `(rating: ${userProfile.rating}). ` +
                `Current time: ${new Date().toISOString()}.`,
            },
          ],
        },
        {
          role: "model",
          parts: [
            {
              text:
                `Hello ${userProfile.displayName}! I'm RallyBot. ` +
                `How can I help you with badminton events today?`,
            },
          ],
        },
        ...(history || []),
      ],
    });

    // 5. Send message and handle function calling loop
    let response = await chat.sendMessage(message);
    let result = response.response;

    // Gemini may return a function call instead of text
    while (result.candidates?.[0]?.content?.parts?.some((p) => p.functionCall)) {
      const functionCall = result.candidates[0].content.parts.find(
        (p) => p.functionCall
      )!.functionCall!;

      let toolResult: any;

      if (functionCall.name === "create_event") {
        toolResult = await executeCreateEvent(
          functionCall.args as any,
          userProfile as any
        );
      } else {
        toolResult = { error: `Unknown tool: ${functionCall.name}` };
      }

      // Send tool result back to Gemini for final response
      response = await chat.sendMessage([
        {
          functionResponse: {
            name: functionCall.name,
            response: toolResult,
          },
        },
      ]);
      result = response.response;
    }

    // 6. Return final text response
    const textResponse = result.candidates?.[0]?.content?.parts
      ?.map((p) => p.text)
      .join("") || "Sorry, I couldn't process that.";

    res.json({
      reply: textResponse,
      // Include event_id if one was created (for client navigation)
      created_event_id: result.candidates?.[0]?.content?.parts?.some(
        (p) => p.functionCall
      )
        ? null
        : undefined,
    });
  }
);
```

---

## Phase 4: Flutter Client — Chatbot UI

### 4.1 New Files to Create

```
lib/
├── provider/
│   └── chat.dart            # ChatProvider (manages messages, API calls)
├── widget/
│   └── chat/
│       ├── chat_screen.dart  # Main chatbot screen
│       └── chat_bubble.dart  # Message bubble widget
└── data/
    └── chat_message.dart     # ChatMessage model
```

### 4.2 Data Model

```dart
// lib/data/chat_message.dart

enum ChatRole { user, bot }

class ChatMessage {
  final String text;
  final ChatRole role;
  final DateTime timestamp;
  final String? createdEventId; // non-null if bot created an event

  ChatMessage({
    required this.text,
    required this.role,
    DateTime? timestamp,
    this.createdEventId,
  }) : timestamp = timestamp ?? DateTime.now();
}
```

### 4.3 Chat Provider

```dart
// lib/provider/chat.dart

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import '../data/chat_message.dart';

class ChatProvider with ChangeNotifier {
  final List<ChatMessage> _messages = [];
  bool _isLoading = false;

  List<ChatMessage> get messages => List.unmodifiable(_messages);
  bool get isLoading => _isLoading;

  // Cloud Function URL (set after deployment)
  static const String _chatEndpoint =
      'https://<REGION>-rallyup-7c3b6.cloudfunctions.net/chat';

  Future<void> sendMessage(String text) async {
    // Add user message
    _messages.add(ChatMessage(text: text, role: ChatRole.user));
    _isLoading = true;
    notifyListeners();

    try {
      // Get Firebase Auth token
      final idToken =
          await FirebaseAuth.instance.currentUser?.getIdToken();

      // Build conversation history for context
      final history = _messages
          .where((m) => m != _messages.last)
          .map((m) => {
                'role': m.role == ChatRole.user ? 'user' : 'model',
                'parts': [{'text': m.text}],
              })
          .toList();

      // Call Cloud Function
      final response = await http.post(
        Uri.parse(_chatEndpoint),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
        body: jsonEncode({
          'message': text,
          'history': history,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _messages.add(ChatMessage(
          text: data['reply'],
          role: ChatRole.bot,
          createdEventId: data['created_event_id'],
        ));
      } else {
        _messages.add(ChatMessage(
          text: 'Sorry, something went wrong. Please try again.',
          role: ChatRole.bot,
        ));
      }
    } catch (e) {
      _messages.add(ChatMessage(
        text: 'Connection error. Please check your network.',
        role: ChatRole.bot,
      ));
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearChat() {
    _messages.clear();
    notifyListeners();
  }
}
```

### 4.4 Chat Screen UI

```dart
// lib/widget/chat/chat_screen.dart

// Full-screen chat interface with:
// - AppBar with "RallyBot" title and clear-chat action
// - ListView.builder for message bubbles (reversed for auto-scroll)
// - Text input bar at bottom with send button
// - Loading indicator when waiting for Gemini response
// - Tappable event cards when createdEventId is non-null
//   (navigates to EventDetailPage)
```

### 4.5 Integration Points

**Register ChatProvider in main.dart:**
```dart
MultiProvider(
  providers: [
    ChangeNotifierProvider(create: (_) => ProfileProvider()..restoreSession()),
    ChangeNotifierProvider(create: (_) => EventProvider()),
    ChangeNotifierProvider(create: (_) => MatchProvider()),
    ChangeNotifierProvider(create: (_) => HistoryEventProvider()),
    ChangeNotifierProvider(create: (_) => ChatProvider()),  // NEW
  ],
  child: MaterialApp(...)
)
```

**Add chat entry point to the UI (two options):**

Option A — FAB on the main screen (alongside existing event list):
```dart
FloatingActionButton(
  onPressed: () => Navigator.push(context,
    MaterialPageRoute(builder: (_) => const ChatScreen())),
  child: const Icon(Icons.smart_toy),
)
```

Option B — Bottom navigation tab (4th tab):
```dart
NavigationDestination(
  icon: Icon(Icons.smart_toy_outlined),
  selectedIcon: Icon(Icons.smart_toy),
  label: 'RallyBot',
)
```

### 4.6 New Dependency

Add `http` package to `pubspec.yaml`:
```yaml
dependencies:
  http: ^1.2.0
```

---

## Phase 5: Conversation Flow Examples

### Example 1: Fully Specified Request

```
User: Create a doubles practice at UW IMA tomorrow from 6pm to 8pm

Bot:  Here's what I'll create:
      - Title: Practice
      - Type: Practice (doubles)
      - Location: UW IMA
      - Time: Jan 28, 2026 6:00 PM – 8:00 PM
      - Rating range: 1200–1600 (based on your rating)

      Should I go ahead and create this event?

User: Yes

Bot:  Done! Your doubles practice at UW IMA has been created.
      Event ID: abc123xyz
      [View Event →]
```

### Example 2: Incremental Conversation

```
User: I want to set up a match

Bot:  I'd be happy to help you set up a competitive match!
      Would you like singles (1v1) or doubles (2v2)?

User: Singles

Bot:  Got it — a singles competition (2 players).
      Where will the match be held?

User: Badminton Center Seattle

Bot:  And when would you like to schedule it?

User: Next Saturday, 3pm to 5pm

Bot:  Here's the summary:
      - Title: Competition
      - Type: Match (singles, 2 players)
      - Location: Badminton Center Seattle
      - Time: Feb 1, 2026 3:00 PM – 5:00 PM
      - Rating range: 1200–1600

      Shall I create this?

User: Change the title to "Weekend Showdown"

Bot:  Updated! Here's the revised summary:
      - Title: Weekend Showdown
      ...
      Shall I create this?

User: Yes!

Bot:  "Weekend Showdown" has been created! 🏸
      [View Event →]
```

---

## Phase 6: Firestore Chat History (Optional Enhancement)

Store chat sessions in Firestore for persistence across app restarts:

```
Firestore collection: chat_sessions
Document: {userId}_{sessionTimestamp}
Fields:
  - userId: string
  - messages: array of { role, text, timestamp, createdEventId? }
  - createdAt: timestamp
  - updatedAt: timestamp
```

This is optional for MVP but useful for users who want to resume conversations.

---

## Implementation Order & Task Breakdown

### Step 1: Backend Setup
- [ ] Initialize Firebase Functions project in `functions/`
- [ ] Configure `GEMINI_API_KEY` in Firebase Secrets
- [ ] Install dependencies (`firebase-admin`, `firebase-functions`, `@google/generative-ai`)
- [ ] Set up TypeScript build pipeline

### Step 2: MCP Tool Implementation
- [ ] Implement `create_event` tool with full validation (mirrors `CreateEventPage` logic)
- [ ] Write the Gemini function declaration schema
- [ ] Add unit tests for parameter validation and business rules
- [ ] Test direct Firestore writes match the existing `EventModel.toFirestore()` format

### Step 3: Gemini Chat Endpoint
- [ ] Implement the `/chat` HTTP Cloud Function
- [ ] Add Firebase Auth middleware (verify ID tokens)
- [ ] Wire up the Gemini function calling loop (message → function_call → execute → respond)
- [ ] Write the system prompt with RallyUp context and rules
- [ ] Test with curl/Postman using a real Firebase auth token

### Step 4: Flutter Client
- [ ] Create `ChatMessage` data model
- [ ] Create `ChatProvider` with HTTP calls to Cloud Function
- [ ] Build `ChatScreen` UI (message list + input bar)
- [ ] Build `ChatBubble` widget (user vs bot styling)
- [ ] Add "View Event" tap action when `createdEventId` is present
- [ ] Register `ChatProvider` in `main.dart`
- [ ] Add chat entry point to the app UI (FAB or nav tab)
- [ ] Add `http` package to `pubspec.yaml`

### Step 5: Testing & Polish
- [ ] End-to-end test: user message → Cloud Function → Gemini → Firestore → client confirmation
- [ ] Test edge cases: missing fields, past dates, invalid locations
- [ ] Test conversation history is maintained across multiple turns
- [ ] Verify created events appear correctly in `EventListView` and `EventDetailPage`
- [ ] Deploy Cloud Function to production

---

## Security Considerations

| Concern | Mitigation |
|---------|-----------|
| Unauthorized event creation | Firebase Auth ID token verification on every request |
| Rating range manipulation | Server calculates from Firestore profile, ignores user input |
| Prompt injection | System prompt is server-side only; user input is passed as chat messages, not system instructions |
| API key exposure | Gemini API key stored in Firebase Secrets, never sent to client |
| Rate limiting | Firebase Cloud Functions support rate limiting via App Check or custom middleware |
| Data consistency | `create_event` tool writes the same Firestore schema as `EventProvider.createEvent()` |

---

## Future MCP Tool Expansions

Once the `create_event` tool is working, additional tools can be added to the same MCP server:

| Tool | Description |
|------|-------------|
| `search_events` | Find events by location, date, type, or rating range |
| `join_event` | Join an open event by ID |
| `my_events` | List the user's upcoming and past events |
| `get_event_details` | Get full details of a specific event |
| `cancel_event` | Cancel an event the user is hosting |
| `suggest_events` | AI-powered event recommendations based on user's rating and history |

Each tool follows the same pattern: define a Gemini function declaration, implement the execution logic with Firestore access, and register it in the tool registry.

---

## Cost Estimates

| Component | Pricing Model |
|-----------|---------------|
| Gemini 2.0 Flash | Free tier: 15 RPM / 1M tokens/day; paid: $0.10/1M input tokens |
| Firebase Cloud Functions | Free tier: 2M invocations/month; pay-as-you-go after |
| Firestore | Free tier: 50K reads, 20K writes/day; pay-as-you-go after |

For a badminton community app, the free tiers should be sufficient during early adoption.
