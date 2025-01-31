import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.7';
import Stripe from 'https://esm.sh/stripe@12.18.0?target=deno';

const stripe = new Stripe(Deno.env.get('STRIPE_SECRET_KEY') || '', {
  apiVersion: '2023-10-16',
  httpClient: Stripe.createFetchHttpClient(),
});

const endpointSecret = Deno.env.get('STRIPE_WEBHOOK_SECRET');

serve(async (req) => {
  try {
    const signature = req.headers.get('stripe-signature');
    if (!signature || !endpointSecret) {
      throw new Error('Missing stripe signature or endpoint secret');
    }

    // Get the raw body
    const body = await req.text();
    
    // Verify webhook signature
    const event = stripe.webhooks.constructEvent(
      body,
      signature,
      endpointSecret
    );

    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    );

    // Handle the event
    switch (event.type) {
      case 'customer.subscription.created':
      case 'customer.subscription.updated': {
        const subscription = event.data.object;
        
        // Update user settings
        const { error: updateError } = await supabaseClient
          .from('user_settings')
          .update({
            stripe_customer_id: subscription.customer,
            subscription_status: subscription.status,
            subscription_plan: subscription.items.data[0].price.nickname?.toLowerCase() || 'basic',
            subscription_period_end: new Date(subscription.current_period_end * 1000).toISOString(),
            cancel_at_period_end: subscription.cancel_at_period_end
          })
          .eq('stripe_customer_id', subscription.customer);

        if (updateError) throw updateError;
        break;
      }

      case 'customer.subscription.deleted': {
        const subscription = event.data.object;
        
        // Reset user to basic plan
        const { error: resetError } = await supabaseClient
          .from('user_settings')
          .update({
            subscription_status: 'canceled',
            subscription_plan: 'basic',
            subscription_period_end: null,
            cancel_at_period_end: false
          })
          .eq('stripe_customer_id', subscription.customer);

        if (resetError) throw resetError;
        break;
      }
    }

    return new Response(JSON.stringify({ received: true }), {
      headers: { 'Content-Type': 'application/json' },
      status: 200,
    });
  } catch (error) {
    return new Response(
      JSON.stringify({ error: error.message }),
      { 
        headers: { 'Content-Type': 'application/json' },
        status: 400,
      }
    );
  }
});