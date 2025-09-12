// src/app/api/collaborative/route.ts
import { NextRequest, NextResponse } from 'next/server';

export async function POST(request: NextRequest) {
  try {
    const { action, data, user } = await request.json();
    
    const timestamp = new Date().toISOString();
    const collaborativeEvent = {
      id: crypto.randomUUID(),
      action,
      data,
      user: user || 'louiewong4@gmail.com',
      timestamp,
      status: 'active'
    };

    // Send to N8N webhook for logging
    // @ts-ignore
    try {
      await fetch(process.env.CLOUD_HOOK!, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          type: 'collaborative_event',
          event: collaborativeEvent,
          source: 'voice_dashboard'
        })
      });
    } catch (webhookError) {
      console.warn('Webhook failed:', webhookError);
    }

    return NextResponse.json({
      success: true,
      event: collaborativeEvent,
      message: 'Collaborative event logged'
    });

  } catch (error) {
    return NextResponse.json(
      { success: false, error: 'Failed to process collaborative event' },
      { status: 500 }
    );
  }
}

export async function GET() {
  return NextResponse.json({
    status: 'active',
    users_online: 1,
    last_activity: new Date().toISOString(),
    features: ['voice_commands', 'worker_deployment', 'real_time_monitoring']
  });
}