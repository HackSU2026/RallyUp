import * as admin from "firebase-admin";
import {Request} from "firebase-functions/v2/https";
import {UserProfile} from "../types";

/**
 * Verifies the Firebase Auth ID token from the Authorization header
 * and loads the user profile from Firestore.
 *
 * Returns the UserProfile or throws an error with a status code.
 */
export async function authenticateRequest(
  req: Request
): Promise<UserProfile> {
  const authHeader = req.headers.authorization;
  if (!authHeader || !authHeader.startsWith("Bearer ")) {
    const err = new Error("Missing or malformed Authorization header");
    (err as any).statusCode = 401;
    throw err;
  }

  const idToken = authHeader.split("Bearer ")[1];

  let decodedToken: admin.auth.DecodedIdToken;
  try {
    decodedToken = await admin.auth().verifyIdToken(idToken);
  } catch {
    const err = new Error("Invalid or expired auth token");
    (err as any).statusCode = 401;
    throw err;
  }

  const userDoc = await admin
    .firestore()
    .collection("users")
    .doc(decodedToken.uid)
    .get();

  if (!userDoc.exists) {
    const err = new Error("User profile not found. Complete onboarding first.");
    (err as any).statusCode = 404;
    throw err;
  }

  const data = userDoc.data()!;
  return {
    uid: decodedToken.uid,
    email: data.email ?? "",
    displayName: data.displayName ?? "Player",
    photoURL: data.photoURL,
    rating: data.rating ?? 1000,
  };
}
