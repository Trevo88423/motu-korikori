/**
 * Cloudflare Worker for handling audio uploads to R2
 *
 * This worker receives audio files from the Next.js app and stores them in R2.
 * It validates the Supabase JWT token to ensure only authenticated users can upload.
 *
 * Environment Variables Required:
 * - R2_BUCKET: The R2 bucket binding
 * - SUPABASE_JWT_SECRET: Supabase JWT secret for token validation
 * - ALLOWED_ORIGIN: The Next.js app origin for CORS
 */

import { createClient } from '@supabase/supabase-js'

export default {
  async fetch(request, env) {
    // CORS headers
    const corsHeaders = {
      'Access-Control-Allow-Origin': env.ALLOWED_ORIGIN || '*',
      'Access-Control-Allow-Methods': 'POST, DELETE, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type, Authorization',
      'Access-Control-Max-Age': '86400',
    }

    // Handle CORS preflight
    if (request.method === 'OPTIONS') {
      return new Response(null, { headers: corsHeaders })
    }

    try {
      // Validate authorization
      const authHeader = request.headers.get('Authorization')
      if (!authHeader || !authHeader.startsWith('Bearer ')) {
        return new Response('Unauthorized', { status: 401 })
      }

      const token = authHeader.substring(7)

      // Validate JWT token with Supabase
      const supabase = createClient(
        env.SUPABASE_URL,
        env.SUPABASE_ANON_KEY
      )

      const { data: { user }, error } = await supabase.auth.getUser(token)

      if (error || !user) {
        return new Response('Invalid token', { status: 401 })
      }

      // Handle POST (upload)
      if (request.method === 'POST') {
        const formData = await request.formData()
        const audioFile = formData.get('audio')
        const wordId = formData.get('wordId')
        const userId = formData.get('userId')

        if (!audioFile || !wordId || !userId) {
          return new Response('Missing required fields', { status: 400 })
        }

        // Validate user ID matches token
        if (userId !== user.id) {
          return new Response('User ID mismatch', { status: 403 })
        }

        // Validate file type
        if (!audioFile.type.startsWith('audio/')) {
          return new Response('Invalid file type', { status: 400 })
        }

        // Validate file size (max 5MB)
        if (audioFile.size > 5 * 1024 * 1024) {
          return new Response('File too large (max 5MB)', { status: 400 })
        }

        // Generate unique filename
        const timestamp = Date.now()
        const filename = `recordings/${wordId}/${userId}_${timestamp}.webm`

        // Upload to R2
        await env.R2_BUCKET.put(filename, audioFile, {
          httpMetadata: {
            contentType: audioFile.type,
          },
          customMetadata: {
            wordId: wordId,
            userId: userId,
            uploadedAt: new Date().toISOString(),
          },
        })

        // Return public URL
        const publicUrl = `${env.R2_PUBLIC_URL}/${filename}`

        return new Response(JSON.stringify({ url: publicUrl }), {
          status: 200,
          headers: {
            'Content-Type': 'application/json',
            ...corsHeaders,
          },
        })
      }

      // Handle DELETE
      if (request.method === 'DELETE') {
        const body = await request.json()
        const { url } = body

        if (!url) {
          return new Response('Missing URL', { status: 400 })
        }

        // Extract filename from URL
        const urlParts = url.split('/')
        const filename = urlParts.slice(-3).join('/') // recordings/wordId/userId_timestamp.webm

        // Verify user owns this file
        if (!filename.includes(user.id)) {
          return new Response('Forbidden', { status: 403 })
        }

        // Delete from R2
        await env.R2_BUCKET.delete(filename)

        return new Response(JSON.stringify({ success: true }), {
          status: 200,
          headers: {
            'Content-Type': 'application/json',
            ...corsHeaders,
          },
        })
      }

      return new Response('Method not allowed', { status: 405 })

    } catch (error) {
      console.error('Worker error:', error)
      return new Response(`Internal error: ${error.message}`, {
        status: 500,
        headers: corsHeaders,
      })
    }
  },
}
