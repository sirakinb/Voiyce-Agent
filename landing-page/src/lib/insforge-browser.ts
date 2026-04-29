import { createClient } from "@insforge/sdk";

import { insforgeAnonKey, insforgeBaseUrl } from "@/lib/voiyce-config";

let client: ReturnType<typeof createClient> | null = null;

export function getInsForgeBrowserClient() {
  if (!client) {
    client = createClient({
      baseUrl: insforgeBaseUrl,
      anonKey: insforgeAnonKey,
    });
  }

  return client;
}
