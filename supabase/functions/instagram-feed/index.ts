import 'jsr:@supabase/functions-js/edge-runtime.d.ts'
import { withSupabase } from 'jsr:@supabase/server@^1'
import { createClient } from 'npm:@supabase/supabase-js@2'

const mediaFields = [
  'id',
  'caption',
  'media_type',
  'media_url',
  'thumbnail_url',
  'permalink',
  'timestamp',
].join(',')

const refreshAfterMilliseconds = 6 * 24 * 60 * 60 * 1000

type StoredToken = {
  access_token: string
  refreshed_at: string
}

async function refreshInstagramToken(accessToken: string) {
  const url = new URL('https://graph.instagram.com/refresh_access_token')
  url.searchParams.set('grant_type', 'ig_refresh_token')
  url.searchParams.set('access_token', accessToken)

  const response = await fetch(url, {
    headers: { Accept: 'application/json' },
  })
  const payload = await response.json()
  if (!response.ok || typeof payload.access_token !== 'string') {
    throw new Error(`Instagram token refresh failed: ${response.status}`)
  }
  return {
    accessToken: payload.access_token as string,
    expiresIn: Number(payload.expires_in ?? 5184000),
  }
}

export default {
  fetch: withSupabase({ auth: 'none' }, async () => {
    const fallbackToken = Deno.env.get('INSTAGRAM_ACCESS_TOKEN')
    const instagramUserId = Deno.env.get('INSTAGRAM_USER_ID')
    const supabaseUrl = Deno.env.get('SUPABASE_URL')
    const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')

    if (!fallbackToken || !instagramUserId || !supabaseUrl || !serviceRoleKey) {
      console.error('Instagram or Supabase secrets are missing')
      return Response.json(
        { error: 'Instagram feed is not configured' },
        { status: 503 },
      )
    }

    const admin = createClient(supabaseUrl, serviceRoleKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    })
    const { data: stored, error: readError } = await admin
      .from('instagram_token_state')
      .select('access_token, refreshed_at')
      .eq('id', true)
      .maybeSingle<StoredToken>()

    if (readError) console.error('Could not read stored Instagram token', readError)
    let accessToken = stored?.access_token ?? fallbackToken
    const refreshedAt = stored?.refreshed_at
      ? Date.parse(stored.refreshed_at)
      : 0

    if (Date.now() - refreshedAt >= refreshAfterMilliseconds) {
      try {
        const refreshed = await refreshInstagramToken(accessToken)
        accessToken = refreshed.accessToken
        const expiresAt = new Date(
          Date.now() + refreshed.expiresIn * 1000,
        ).toISOString()
        const { error: storeError } = await admin
          .from('instagram_token_state')
          .upsert({
            id: true,
            access_token: accessToken,
            refreshed_at: new Date().toISOString(),
            expires_at: expiresAt,
          })
        if (storeError) console.error('Could not store refreshed token', storeError)
      } catch (error) {
        // Der vorhandene Token wird weiterverwendet. So bleibt der Feed bei
        // einem kurzfristigen Meta-Ausfall erreichbar.
        console.error('Instagram token refresh failed', error)
      }
    }

    const url = new URL(`https://graph.instagram.com/${instagramUserId}/media`)
    url.searchParams.set('fields', mediaFields)
    url.searchParams.set('limit', '12')
    url.searchParams.set('access_token', accessToken)

    try {
      const instagramResponse = await fetch(url, {
        headers: { Accept: 'application/json' },
      })
      const payload = await instagramResponse.json()

      if (!instagramResponse.ok) {
        console.error('Instagram API error', payload)
        return Response.json(
          { error: 'Instagram feed is temporarily unavailable' },
          { status: 502 },
        )
      }

      return Response.json(
        { posts: Array.isArray(payload.data) ? payload.data : [] },
        { headers: { 'Cache-Control': 'public, max-age=300, s-maxage=900' } },
      )
    } catch (error) {
      console.error('Instagram request failed', error)
      return Response.json(
        { error: 'Instagram feed is temporarily unavailable' },
        { status: 502 },
      )
    }
  }),
}
