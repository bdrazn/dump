import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.7';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? ''
    );

    // Get request body
    const { to, message, contactId } = await req.json();

    if (!to || !message || !contactId) {
      throw new Error('Missing required parameters: to, message, or contactId');
    }

    // Get user from auth header
    const authHeader = req.headers.get('Authorization');
    if (!authHeader) {
      throw new Error('No authorization header');
    }

    const { data: { user }, error: userError } = await supabaseClient.auth.getUser(
      authHeader.replace('Bearer ', '')
    );

    if (userError || !user) {
      throw new Error('Not authenticated');
    }

    // Get user settings
    const { data: settings, error: settingsError } = await supabaseClient
      .from('user_settings')
      .select('smrtphone_api_key, phone_number_1')
      .eq('user_id', user.id)
      .single();

    if (settingsError || !settings?.smrtphone_api_key) {
      throw new Error('SMS API key not configured');
    }

    if (!settings.phone_number_1) {
      throw new Error('No sending phone number configured');
    }

    // Get workspace ID
    const { data: workspace, error: workspaceError } = await supabaseClient
      .from('workspace_users')
      .select('workspace_id')
      .eq('user_id', user.id)
      .single();

    if (workspaceError || !workspace) {
      throw new Error('No workspace found');
    }

    // Clean phone numbers
    const cleanFromNumber = settings.phone_number_1.replace(/[^\d]/g, '');
    const cleanToNumber = to.replace(/[^\d]/g, '');

    // Get or create message thread
    const { data: thread, error: threadError } = await supabaseClient
      .rpc('get_or_create_message_thread', {
        p_workspace_id: workspace.workspace_id,
        p_contact_id: contactId,
        p_direction: 'outbound'
      });

    if (threadError) throw threadError;

    // Store the message first
    const { data: messageData, error: messageError } = await supabaseClient
      .from('messages')
      .insert({
        thread_id: thread,
        content: message,
        sender_id: user.id,
        direction: 'outbound'
      })
      .select()
      .single();

    if (messageError) throw messageError;

    // Prepare URL-encoded body
    const urlEncodedBody = new URLSearchParams();
    urlEncodedBody.append("from", cleanFromNumber);
    urlEncodedBody.append("to", cleanToNumber);
    urlEncodedBody.append("message", message);

    // Send the SMS
    const apiUrl = 'https://api.smrtphone.io/v1/messages';
    const response = await fetch(apiUrl, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
        'X-Auth-smrtPhone': settings.smrtphone_api_key
      },
      body: urlEncodedBody.toString()
    });

    if (!response.ok) {
      const errorText = await response.text();
      console.error('SMS API Error Response:', {
        status: response.status,
        statusText: response.statusText,
        body: errorText
      });
      throw new Error(`Failed to send SMS: ${response.statusText}`);
    }

    const data = await response.json();

    // Store the SMS details
    await supabaseClient
      .from('smrtphone_messages')
      .insert({
        workspace_id: workspace.workspace_id,
        thread_id: thread,
        external_id: data.messageId,
        from_number: cleanFromNumber,
        to_number: cleanToNumber,
        content: message,
        status: 'sent',
        direction: 'outbound'
      });

    return new Response(
      JSON.stringify({ success: true, messageId: data.messageId }),
      { 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200 
      }
    );
  } catch (error) {
    console.error('Error:', error);
    return new Response(
      JSON.stringify({ 
        success: false, 
        error: error instanceof Error ? error.message : 'An unknown error occurred' 
      }),
      { 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 400 
      }
    );
  }
});