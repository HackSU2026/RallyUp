import {createEventDeclaration, executeCreateEvent} from "./create_event";
import {UserProfile, ToolResult} from "../types";

/**
 * Registry of all MCP tools available to Gemini.
 * Add new tools here as they are implemented.
 */
export const toolDeclarations = [createEventDeclaration];

/**
 * Dispatches a function call from Gemini to the appropriate tool executor.
 */
export async function executeTool(
  name: string,
  args: Record<string, any>,
  user: UserProfile
): Promise<ToolResult> {
  switch (name) {
  case "create_event":
    return executeCreateEvent(args as any, user);
  default:
    return {success: false, error: `Unknown tool: ${name}`};
  }
}
