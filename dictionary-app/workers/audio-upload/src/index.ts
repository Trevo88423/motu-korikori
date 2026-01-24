/**
 * Cloudflare Worker for handling audio uploads to R2
 * Motu Dictionary Project
 */

export interface Env {
  AUDIO_BUCKET: R2Bucket;
  ALLOWED_ORIGINS: string;
  SUPABASE_JWT_SECRET?: string;
}

// CORS headers
function corsHeaders(origin: string, allowedOrigins: string): HeadersInit {
  const origins = allowedOrigins.split(',').map(o => o.trim());
  const allowOrigin = origins.includes(origin) ? origin : origins[0];

  return {
    'Access-Control-Allow-Origin': allowOrigin,
    'Access-Control-Allow-Methods': 'GET, POST, DELETE, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type, Authorization',
    'Access-Control-Max-Age': '86400',
  };
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);
    const origin = request.headers.get('Origin') || '';
    const headers = corsHeaders(origin, env.ALLOWED_ORIGINS);

    // Handle CORS preflight
    if (request.method === 'OPTIONS') {
      return new Response(null, { headers });
    }

    try {
      // GET - Retrieve/serve audio file
      if (request.method === 'GET') {
        const key = url.pathname.slice(1); // Remove leading slash

        if (!key) {
          return new Response(JSON.stringify({ error: 'No file key provided' }), {
            status: 400,
            headers: { ...headers, 'Content-Type': 'application/json' },
          });
        }

        const object = await env.AUDIO_BUCKET.get(key);

        if (!object) {
          return new Response(JSON.stringify({ error: 'File not found' }), {
            status: 404,
            headers: { ...headers, 'Content-Type': 'application/json' },
          });
        }

        const fileHeaders = new Headers();
        object.writeHttpMetadata(fileHeaders);
        fileHeaders.set('etag', object.httpEtag);

        // Add CORS headers
        Object.entries(headers).forEach(([key, value]) => {
          fileHeaders.set(key, value as string);
        });

        return new Response(object.body, {
          headers: fileHeaders,
        });
      }

      // POST - Upload audio file
      if (request.method === 'POST') {
        // Verify authorization
        const authHeader = request.headers.get('Authorization');
        if (!authHeader?.startsWith('Bearer ')) {
          return new Response(JSON.stringify({ error: 'Unauthorized' }), {
            status: 401,
            headers: { ...headers, 'Content-Type': 'application/json' },
          });
        }

        // Parse form data
        const formData = await request.formData();
        const audioFile = formData.get('audio') as File | null;
        const wordId = formData.get('wordId') as string | null;
        const userId = formData.get('userId') as string | null;

        if (!audioFile || !wordId || !userId) {
          return new Response(JSON.stringify({ error: 'Missing required fields: audio, wordId, userId' }), {
            status: 400,
            headers: { ...headers, 'Content-Type': 'application/json' },
          });
        }

        // Generate unique filename
        const timestamp = Date.now();
        const extension = audioFile.name.split('.').pop() || 'webm';
        const key = `audio/${wordId}/${userId}_${timestamp}.${extension}`;

        // Upload to R2
        const arrayBuffer = await audioFile.arrayBuffer();
        await env.AUDIO_BUCKET.put(key, arrayBuffer, {
          httpMetadata: {
            contentType: audioFile.type || 'audio/webm',
          },
          customMetadata: {
            wordId,
            userId,
            uploadedAt: new Date().toISOString(),
          },
        });

        // Return the URL to access this file
        const fileUrl = `${url.origin}/${key}`;

        return new Response(JSON.stringify({
          success: true,
          url: fileUrl,
          key
        }), {
          status: 200,
          headers: { ...headers, 'Content-Type': 'application/json' },
        });
      }

      // DELETE - Remove audio file
      if (request.method === 'DELETE') {
        // Verify authorization
        const authHeader = request.headers.get('Authorization');
        if (!authHeader?.startsWith('Bearer ')) {
          return new Response(JSON.stringify({ error: 'Unauthorized' }), {
            status: 401,
            headers: { ...headers, 'Content-Type': 'application/json' },
          });
        }

        const body = await request.json() as { url?: string; key?: string };
        let key = body.key;

        // Extract key from URL if provided
        if (!key && body.url) {
          const fileUrl = new URL(body.url);
          key = fileUrl.pathname.slice(1);
        }

        if (!key) {
          return new Response(JSON.stringify({ error: 'No file key or URL provided' }), {
            status: 400,
            headers: { ...headers, 'Content-Type': 'application/json' },
          });
        }

        await env.AUDIO_BUCKET.delete(key);

        return new Response(JSON.stringify({ success: true }), {
          status: 200,
          headers: { ...headers, 'Content-Type': 'application/json' },
        });
      }

      return new Response(JSON.stringify({ error: 'Method not allowed' }), {
        status: 405,
        headers: { ...headers, 'Content-Type': 'application/json' },
      });

    } catch (error: any) {
      console.error('Worker error:', error);
      return new Response(JSON.stringify({ error: error.message || 'Internal server error' }), {
        status: 500,
        headers: { ...headers, 'Content-Type': 'application/json' },
      });
    }
  },
};
