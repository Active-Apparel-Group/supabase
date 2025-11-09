/// <reference types="https://deno.land/x/deno@v1.32.0/cli/tsc/dts/lib.deno.d.ts" />
/**
 * Local BeProduct Authentication Test
 * Run with: deno run --allow-net --allow-env --allow-read scripts/test-beproduct-auth.ts
 */

import "https://deno.land/std@0.192.0/dotenv/load.ts";

// @ts-expect-error: Deno global for type checking
declare const Deno: any;
const BASE_URL = "https://developers.beproduct.com";
const TOKEN_URL = `${BASE_URL}/connect/token`;

interface TokenResponse {
  access_token: string;
  expires_in: number;
  token_type: string;
  scope?: string;
}

/**
 * Test 1: Get access token using refresh token grant
 */
async function testRefreshTokenGrant(): Promise<string | null> {
  console.log("\n=== Test 1: Refresh Token Grant ===");
  
  const clientId = Deno.env.get("BEPRODUCT_CLIENT_ID");
  const clientSecret = Deno.env.get("BEPRODUCT_CLIENT_SECRET");
  const refreshToken = Deno.env.get("BEPRODUCT_REFRESH_TOKEN");
  
  console.log(`Client ID: ${clientId}`);
  console.log(`Client Secret: ${clientSecret?.substring(0, 10)}...`);
  console.log(`Refresh Token: ${refreshToken?.substring(0, 10)}...`);
  
  if (!clientId || !clientSecret || !refreshToken) {
    console.error("❌ Missing required environment variables");
    return null;
  }

  const params = new URLSearchParams({
    grant_type: "refresh_token",
    client_id: clientId,
    client_secret: clientSecret,
    refresh_token: refreshToken,
    scope: "openid profile email roles BeProductPublicApi",
  });

  console.log(`\nPOST ${TOKEN_URL}`);
  console.log(`Body: ${params.toString()}`);

  try {
    const response = await fetch(TOKEN_URL, {
      method: "POST",
      headers: {
        "Content-Type": "application/x-www-form-urlencoded",
      },
      body: params.toString(),
    });

    console.log(`Status: ${response.status} ${response.statusText}`);
    
    if (!response.ok) {
      const errorText = await response.text();
      console.error(`❌ Token request failed: ${errorText}`);
      return null;
    }

    const data: TokenResponse = await response.json();
    console.log(`✅ Token received`);
    console.log(`   Type: ${data.token_type}`);
    console.log(`   Expires in: ${data.expires_in}s`);
    console.log(`   Scope: ${data.scope || 'not specified'}`);
    console.log(`   Token prefix: ${data.access_token.substring(0, 30)}...`);
    console.log(`   Token length: ${data.access_token.length} chars`);
    
    return data.access_token;
  } catch (error) {
    console.error(`❌ Exception during token request:`, error);
    return null;
  }
}

/**
 * Test 2: Get access token using client credentials grant (fallback)
 */
async function testClientCredentialsGrant(): Promise<string | null> {
  console.log("\n=== Test 2: Client Credentials Grant ===");
  
  const clientId = Deno.env.get("BEPRODUCT_CLIENT_ID");
  const clientSecret = Deno.env.get("BEPRODUCT_CLIENT_SECRET");
  
  if (!clientId || !clientSecret) {
    console.error("❌ Missing required environment variables");
    return null;
  }

  const params = new URLSearchParams({
    grant_type: "client_credentials",
    client_id: clientId,
    client_secret: clientSecret,
    scope: "openid profile email roles BeProductPublicApi",
  });

  console.log(`\nPOST ${TOKEN_URL}`);
  console.log(`Body: ${params.toString()}`);

  try {
    const response = await fetch(TOKEN_URL, {
      method: "POST",
      headers: {
        "Content-Type": "application/x-www-form-urlencoded",
      },
      body: params.toString(),
    });

    console.log(`Status: ${response.status} ${response.statusText}`);
    
    if (!response.ok) {
      const errorText = await response.text();
      console.error(`❌ Token request failed: ${errorText}`);
      return null;
    }

    const data: TokenResponse = await response.json();
    console.log(`✅ Token received`);
    console.log(`   Type: ${data.token_type}`);
    console.log(`   Expires in: ${data.expires_in}s`);
    console.log(`   Scope: ${data.scope || 'not specified'}`);
    console.log(`   Token prefix: ${data.access_token.substring(0, 30)}...`);
    console.log(`   Token length: ${data.access_token.length} chars`);
    
    return data.access_token;
  } catch (error) {
    console.error(`❌ Exception during token request:`, error);
    return null;
  }
}

/**
 * Test 3: Call BeProduct API with access token
 */
async function testMasterdataAPI(token: string): Promise<void> {
  console.log("\n=== Test 3: MasterData API Call ===");
  
  const company = Deno.env.get("BEPRODUCT_COMPANY");
  const fieldId = "brand_1"; // Test with brand_1 field
  const url = `${BASE_URL}/api/${company}/MasterData/Field/${fieldId}`;
  
  console.log(`\nGET ${url}`);
  console.log(`Authorization: Bearer ${token.substring(0, 30)}...`);

  try {
    const response = await fetch(url, {
      method: "GET",
      headers: {
        "Authorization": `Bearer ${token}`,
        "Accept": "application/json",
        "User-Agent": "Supabase-Edge-Function/1.0",
      },
    });

    console.log(`Status: ${response.status} ${response.statusText}`);
    
    if (!response.ok) {
      const errorText = await response.text();
      console.error(`❌ API request failed: ${errorText}`);
      return;
    }

    const data = await response.json();
    console.log(`✅ API call successful`);
    console.log(`   Field ID: ${data.id}`);
    console.log(`   Field Name: ${data.name}`);
    console.log(`   Choices count: ${data.choices?.length || 0}`);
    
    if (data.choices && data.choices.length > 0) {
      console.log(`   First 3 choices: ${data.choices.slice(0, 3).map((c: any) => c.name).join(", ")}`);
    }
  } catch (error) {
    console.error(`❌ Exception during API request:`, error);
  }
}

/**
 * Main test runner
 */
async function main() {
  console.log("╔══════════════════════════════════════════╗");
  console.log("║  BeProduct Authentication Test Suite    ║");
  console.log("╚══════════════════════════════════════════╝");
  
  // Test refresh token grant first
  let token = await testRefreshTokenGrant();
  
  // Fallback to client credentials if refresh token fails
  if (!token) {
    console.log("\n⚠️  Refresh token grant failed, trying client credentials...");
    token = await testClientCredentialsGrant();
  }
  
  // Test API call if we have a token
  if (token) {
    await testMasterdataAPI(token);
    console.log("\n✅ All tests completed successfully!");
  } else {
    console.log("\n❌ Unable to obtain access token. Please check your credentials.");
    Deno.exit(1);
  }
}

// Run the tests
main();
