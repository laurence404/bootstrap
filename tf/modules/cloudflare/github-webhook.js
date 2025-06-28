addEventListener('fetch', (event) => {
    event.respondWith(handleRequest(event.request));
});

/**
 * Handles incoming HTTP requests.
 *
 * @param {Request} request The incoming HTTP request.
 * @returns {Promise<Response>} A Promise that resolves to the HTTP response.
 */
async function handleRequest(request) {
    // Only process POST requests.
    if (request.method !== 'POST') {
        return new Response('Method Not Allowed', { status: 405 });
    }

    // Get the raw request body.
    let body;
    try {
        body = await request.text();
    } catch (error) {
        console.error('Error reading request body:', error);
        return new Response('Error reading request body', { status: 500 });
    }

    // Get the signature from the `X-Hub-Signature-256` header.
    const signature = request.headers.get('X-Hub-Signature-256');
    if (!signature) {
        console.error('Missing X-Hub-Signature-256 header');
        return new Response('Missing X-Hub-Signature-256 header', { status: 400 });
    }

    // Verify the signature.
    const isValid = await verifySignature(body, signature);
    if (!isValid) {
        console.error('Invalid signature');
        return new Response('Invalid signature', { status: 401 });
    }

    // Forward the request to the upstream service.
    return forwardRequest(request, body);
}

/**
 * Verifies the signature of the incoming request.
 *
 * @param {string} body The raw body of the request.
 * @param {string} signature The signature from the `X-Hub-Signature-256` header.
 * @returns {Promise<boolean>} A Promise that resolves to `true` if the signature
 * is valid, and `false` otherwise.
 */
async function verifySignature(body, signature) {
    try {
        // 1. Decode the signature from the header.  It comes as "sha256=<hex>".
        const [algorithm, expectedHex] = signature.split('=');
        if (algorithm !== 'sha256' || !expectedHex) {
            console.error('Invalid signature format');
            return false;
        }
        const expectedSignatureBytes = hexToBytes(expectedHex); // Convert hex to bytes.

        // 2. Convert the secret to a key.
        const key = await crypto.subtle.importKey(
            'raw',
            new TextEncoder().encode(`${WEBHOOK_SECRET}`),
            { name: 'HMAC', hash: { name: 'SHA-256' } },
            false,
            ['sign', 'verify'],
        );

        // 3. Calculate the HMAC-SHA256 signature of the body.
        const bodyBuffer = new TextEncoder().encode(body);

        // 4. Verify the signature using crypto.subtle.verify
        const isValid = await crypto.subtle.verify(
            'HMAC',
            key,
            expectedSignatureBytes,
            bodyBuffer,
        );

        return isValid;
    } catch (error) {
        console.error('Error verifying signature:', error);
        return false;
    }
}

/**
 * Converts a hexadecimal string to a byte array.
 *
 * @param {string} hex The hexadecimal string to convert.
 * @returns {Uint8Array} A byte array representing the hexadecimal string.
 */
function hexToBytes(hex) {
    const bytes = new Uint8Array(hex.length / 2);
    for (let i = 0; i < hex.length; i += 2) {
        bytes[i / 2] = parseInt(hex.substring(i, i + 2), 16);
    }
    return bytes;
}

/**
 * Forwards the request to the upstream service
 *
 * @param {string} body The raw body of the request (the GitHub payload).
 * @returns {Promise<Response>} A Promise that resolves to the HTTP response
 * from the upstream service.
 */
async function forwardRequest(request, body) {
    try {
        const headers = new Headers(request.headers); // Copy original headers
        // Forward the request to the upstream service.
        const upstreamResponse = await fetch(request.url, {
            method: 'POST',
            headers: headers,
            body: body,
        });

        // Return the response from the upstream service to the client.
        return new Response(await upstreamResponse.text(), {
            status: upstreamResponse.status,
            headers: upstreamResponse.headers, // Forward headers
        });
    } catch (error) {
        console.error('Error forwarding request:', error);
        return new Response('Error forwarding request', { status: 500 });
    }
}