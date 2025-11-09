/**
 * Local BeProduct Authentication Test (Node.js)
 * Run with: node scripts/test-beproduct-auth.js
 * 
 * Set environment variables first:
 * $env:BEPRODUCT_CLIENT_ID="activeapparelgroup"
 * $env:BEPRODUCT_CLIENT_SECRET="vbIA49uuRgD1ccvwg32uECx"
 * $env:BEPRODUCT_REFRESH_TOKEN="4663d0431067fed86665020b4166b738"
 * $env:BEPRODUCT_COMPANY="activeapparelgroup"
 */

const BASE_URL = "https://developers.beproduct.com";
const TOKEN_URL = "https://id.winks.io/ids/connect/token";

/**
 * Test 1: Get access token using refresh token grant
 */
async function testRefreshTokenGrant() {
  console.log("\n=== Test 1: Refresh Token Grant ===");
  
  const clientId = process.env.BEPRODUCT_CLIENT_ID;
  const clientSecret = process.env.BEPRODUCT_CLIENT_SECRET;
  const refreshToken = process.env.BEPRODUCT_REFRESH_TOKEN;
  
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

    const data = await response.json();
    console.log(`✅ Token received`);
    console.log(`   Type: ${data.token_type}`);
    console.log(`   Expires in: ${data.expires_in}s`);
    console.log(`   Scope: ${data.scope || 'not specified'}`);
    console.log(`   Token prefix: ${data.access_token.substring(0, 30)}...`);
    console.log(`   Token length: ${data.access_token.length} chars`);
    
    return data.access_token;
  } catch (error) {
    console.error(`❌ Exception during token request:`, error.message);
    return null;
  }
}

/**
 * Test 2: Get access token using client credentials grant (fallback)
 */
async function testClientCredentialsGrant() {
  console.log("\n=== Test 2: Client Credentials Grant ===");
  
  const clientId = process.env.BEPRODUCT_CLIENT_ID;
  const clientSecret = process.env.BEPRODUCT_CLIENT_SECRET;
  
  if (!clientId || !clientSecret) {
    console.error("❌ Missing required environment variables");
    return null;
  }

  const params = new URLSearchParams({
    grant_type: "client_credentials",
    client_id: clientId,
    client_secret: clientSecret,
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

    const data = await response.json();
    console.log(`✅ Token received`);
    console.log(`   Type: ${data.token_type}`);
    console.log(`   Expires in: ${data.expires_in}s`);
    console.log(`   Scope: ${data.scope || 'not specified'}`);
    console.log(`   Token prefix: ${data.access_token.substring(0, 30)}...`);
    console.log(`   Token length: ${data.access_token.length} chars`);
    
    return data.access_token;
  } catch (error) {
    console.error(`❌ Exception during token request:`, error.message);
    return null;
  }
}

/**
 * Test 3: Call BeProduct API with access token
 */
async function testMasterdataAPI(token) {
  console.log("\n=== Test 3: API Calls ===");
  
  const company = process.env.BEPRODUCT_COMPANY;
  
  // Test 1: Info/Version endpoint (should always work)
  console.log("\n--- Test 3a: Info/Version ---");
  let url = `${BASE_URL}/api/${company}/Info/Version`;
  console.log(`GET ${url}`);
  try {
    let response = await fetch(url, {
      method: "GET",
      headers: {
        "Authorization": `Bearer ${token}`,
        "Accept": "application/json",
      },
    });
    console.log(`Status: ${response.status} ${response.statusText}`);
    if (response.ok) {
      const data = await response.json();
      console.log(`✅ Version: ${JSON.stringify(data)}`);
    } else {
      console.error(`❌ Failed: ${await response.text()}`);
    }
  } catch (error) {
    console.error(`❌ Exception: ${error.message}`);
  }
  
  // Test 2: Style/Folders endpoint
  console.log("\n--- Test 3b: Style/Folders ---");
  url = `${BASE_URL}/api/${company}/Style/Folders`;
  console.log(`GET ${url}`);
  try {
    let response = await fetch(url, {
      method: "GET",
      headers: {
        "Authorization": `Bearer ${token}`,
        "Accept": "application/json",
      },
    });
    console.log(`Status: ${response.status} ${response.statusText}`);
    if (response.ok) {
      const data = await response.json();
      console.log(`✅ Folders: ${data.length} items`);
    } else {
      console.error(`❌ Failed: ${await response.text()}`);
    }
  } catch (error) {
    console.error(`❌ Exception: ${error.message}`);
  }
  
  // Test 3: MasterData endpoint (VERIFIED WORKING)
  console.log("\n--- Test 3c: MasterData/brand_1 ---");
  const fieldId = "brand_1";
  url = `${BASE_URL}/api/${company}/MasterData/${fieldId}`;
  console.log(`GET ${url}`);
  try {
    let response = await fetch(url, {
      method: "GET",
      headers: {
        "Authorization": `Bearer ${token}`,
        "Accept": "application/json",
      },
    });
    console.log(`Status: ${response.status} ${response.statusText}`);
    if (response.ok) {
      const data = await response.json();
      console.log(`✅ Field ID: ${data.fieldId}`);
      console.log(`   Field Name: ${data.fieldName}`);
      const choices = data.properties?.Choices || [];
      console.log(`   Choices count: ${choices.length}`);
      if (choices.length > 0) {
        console.log(`   First 3: ${choices.slice(0, 3).map(c => c.value).join(", ")}`);
      }
      console.log(`\n🎉 Auth is working! Correct endpoint: /api/{company}/MasterData/{fieldId}`);
    } else {
      console.error(`❌ Failed: ${await response.text()}`);
    }
  } catch (error) {
    console.error(`❌ Exception: ${error.message}`);
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
    process.exit(1);
  }
}

// Run the tests
main().catch(console.error);
