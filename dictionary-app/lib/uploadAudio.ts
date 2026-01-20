/**
 * Upload audio file to Cloudflare R2 via Worker
 */

export async function uploadAudio(
  blob: Blob,
  wordId: string,
  userId: string,
  authToken: string
): Promise<string> {
  const workerUrl = process.env.NEXT_PUBLIC_CLOUDFLARE_WORKER_URL

  if (!workerUrl) {
    throw new Error('Cloudflare Worker URL not configured')
  }

  // Create form data
  const formData = new FormData()
  formData.append('audio', blob, `${wordId}_${userId}_${Date.now()}.webm`)
  formData.append('wordId', wordId)
  formData.append('userId', userId)

  try {
    const response = await fetch(workerUrl, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${authToken}`,
      },
      body: formData,
    })

    if (!response.ok) {
      const error = await response.text()
      throw new Error(`Upload failed: ${error}`)
    }

    const data = await response.json()

    if (!data.url) {
      throw new Error('No URL returned from upload')
    }

    return data.url

  } catch (error: any) {
    console.error('Audio upload error:', error)
    throw new Error(error.message || 'Failed to upload audio')
  }
}

/**
 * Delete audio file from R2
 */
export async function deleteAudio(
  audioUrl: string,
  authToken: string
): Promise<void> {
  const workerUrl = process.env.NEXT_PUBLIC_CLOUDFLARE_WORKER_URL

  if (!workerUrl) {
    throw new Error('Cloudflare Worker URL not configured')
  }

  try {
    const response = await fetch(workerUrl, {
      method: 'DELETE',
      headers: {
        'Authorization': `Bearer ${authToken}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ url: audioUrl }),
    })

    if (!response.ok) {
      const error = await response.text()
      throw new Error(`Delete failed: ${error}`)
    }

  } catch (error: any) {
    console.error('Audio delete error:', error)
    throw new Error(error.message || 'Failed to delete audio')
  }
}
