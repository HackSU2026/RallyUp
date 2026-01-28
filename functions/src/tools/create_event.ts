import * as admin from "firebase-admin";
import {FunctionDeclarationSchemaType} from "@google/generative-ai";
import {CreateEventParams, UserProfile, ToolResult} from "../types";

/**
 * Gemini function declaration for the create_event tool.
 * Defines the schema so Gemini knows how to call it.
 */
export const createEventDeclaration = {
  name: "create_event",
  description:
    "Creates a new badminton event (practice session or competition match) " +
    "in RallyUp. The authenticated user becomes the host and first participant. " +
    "Rating range is auto-calculated from the host's current rating (±200).",
  parameters: {
    type: FunctionDeclarationSchemaType.OBJECT,
    properties: {
      title: {
        type: FunctionDeclarationSchemaType.STRING,
        description:
          "Event title. If omitted or empty, defaults to " +
          "'Practice' or 'Competition' based on event_type.",
      },
      event_type: {
        type: FunctionDeclarationSchemaType.STRING,
        description:
          "Type of event. 'practice' = casual practice (up to 9999 participants). " +
          "'match' = competitive match (fixed headcount: 2 for singles, 4 for doubles).",
      },
      variant: {
        type: FunctionDeclarationSchemaType.STRING,
        description:
          "Badminton variant. 'singles' = 1v1. 'doubles' = 2v2.",
      },
      location: {
        type: FunctionDeclarationSchemaType.STRING,
        description:
          "Event location. Ideally a Google Maps URL, but a venue name or address is also accepted.",
      },
      start_at: {
        type: FunctionDeclarationSchemaType.STRING,
        description:
          "Event start time in ISO 8601 format (e.g. '2025-06-15T18:00:00'). " +
          "Must be in the future.",
      },
      end_at: {
        type: FunctionDeclarationSchemaType.STRING,
        description:
          "Event end time in ISO 8601 format. Must be after start_at.",
      },
    },
    required: ["event_type", "variant", "location", "start_at", "end_at"],
  },
};

/**
 * Executes the create_event tool: validates parameters, enforces business
 * rules, and writes to Firestore.
 */
export async function executeCreateEvent(
  params: CreateEventParams,
  user: UserProfile
): Promise<ToolResult> {
  const db = admin.firestore();

  // 1. Validate event_type
  if (!["practice", "match"].includes(params.event_type)) {
    return {
      success: false,
      error: `Invalid event_type "${params.event_type}". Must be "practice" or "match".`,
    };
  }

  // 2. Validate variant
  if (!["singles", "doubles"].includes(params.variant)) {
    return {
      success: false,
      error: `Invalid variant "${params.variant}". Must be "singles" or "doubles".`,
    };
  }

  // 3. Validate location
  if (!params.location || params.location.trim().length === 0) {
    return {success: false, error: "Location is required."};
  }

  // 4. Parse and validate dates
  const startAt = new Date(params.start_at);
  const endAt = new Date(params.end_at);
  const now = new Date();

  if (isNaN(startAt.getTime()) || isNaN(endAt.getTime())) {
    return {success: false, error: "Invalid date format. Use ISO 8601."};
  }
  if (startAt <= now) {
    return {success: false, error: "Start time must be in the future."};
  }
  if (endAt <= startAt) {
    return {success: false, error: "End time must be after start time."};
  }

  // 5. Calculate business-rule fields
  const isCompetition = params.event_type === "match";
  const maxParticipants = isCompetition
    ? (params.variant === "doubles" ? 4 : 2)
    : 9999;

  const title =
    params.title?.trim() || (isCompetition ? "Competition" : "Practice");

  const minRating = user.rating - 200;
  const maxRating = user.rating + 200;

  // 6. Write to Firestore (matches EventModel.toFirestore() schema)
  const eventData = {
    title,
    eventType: params.event_type,
    hostId: user.uid,
    location: params.location.trim(),
    variant: params.variant,
    ratingRange: {min: minRating, max: maxRating},
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
      `at ${params.location.trim()}, ` +
      `from ${startAt.toISOString()} to ${endAt.toISOString()}. ` +
      `Rating range: ${minRating}–${maxRating}. ` +
      `Max participants: ${maxParticipants}. ` +
      `Event ID: ${docRef.id}`,
  };
}
