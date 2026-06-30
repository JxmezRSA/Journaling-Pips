// Example Supabase Edge Function / Deno endpoint for Journaling Pips.
//
// Security:
// - Never put OPENAI_API_KEY in the iOS app.
// - Add OPENAI_API_KEY as a Supabase project secret or server environment variable.
// - The iOS app should call this endpoint, not OpenAI directly.
//
// Supabase example:
// supabase secrets set OPENAI_API_KEY=sk-...
// supabase functions deploy ai-trade-review

import OpenAI from "npm:openai";

type AIReviewRequest = {
  trade: {
    pair: string;
    direction: string;
    outcome: string;
    profitLoss: number;
    riskReward: number;
    session: string;
    strategy: string;
    mistakes: string[];
    notes: string;
    executionReview: string;
    psychologyNotes: string;
    screenshotsCount: number;
  };
  morningPlan: {
    bias: string;
    checklistCompletion: number;
  };
  recentTradeStats: {
    totalTrades: number;
    winRate: number;
    netProfit: number;
    averageRiskReward: number;
    currentStreak: string;
  };
  coachingStyle: string;
};

type AIReviewResponse = {
  overallScore: number;
  grade: string;
  executionScore: number;
  riskScore: number;
  psychologyScore: number;
  journalQualityScore: number;
  strategyDisciplineScore: number;
  summary: string;
  strengths: string[];
  improvements: string[];
  psychologyNotes: string;
  nextTradeFocus: string;
  riskFeedback: string;
  patternWarnings: string[];
  confidenceLevel: string;
};

const openai = new OpenAI({
  apiKey: Deno.env.get("OPENAI_API_KEY"),
});

Deno.serve(async (request: Request) => {
  if (request.method === "GET") {
    return Response.json({ ok: true, service: "journaling-pips-ai" });
  }

  if (request.method !== "POST") {
    return Response.json({ error: "Method not allowed" }, { status: 405 });
  }

  if (!Deno.env.get("OPENAI_API_KEY")) {
    return Response.json({ error: "OPENAI_API_KEY is not configured" }, { status: 500 });
  }

  const payload = (await request.json()) as AIReviewRequest;

  const response = await openai.responses.create({
    model: "gpt-4.1-mini",
    input: [
      {
        role: "system",
        content:
          "You are a professional trading performance coach. Return only valid JSON matching the requested schema. Do not give financial advice or trade signals.",
      },
      {
        role: "user",
        content: JSON.stringify({
          instruction:
            "Review this completed trade for discipline, risk, execution, psychology, journal quality, and next-trade focus.",
          schema: {
            overallScore: "integer 0-100",
            grade: "A+, A, B, C, D, or F",
            executionScore: "integer 0-100",
            riskScore: "integer 0-100",
            psychologyScore: "integer 0-100",
            journalQualityScore: "integer 0-100",
            strategyDisciplineScore: "integer 0-100",
            summary: "short coaching summary",
            strengths: "array of concise strengths",
            improvements: "array of concise improvements",
            psychologyNotes: "short psychology review",
            nextTradeFocus: "one practical focus for next trade",
            riskFeedback: "short risk-management feedback",
            patternWarnings: "array of possible behavior warnings",
            confidenceLevel: "Low, Medium, or High",
          },
          tradeReviewRequest: payload,
        }),
      },
    ],
  });

  const text = response.output_text ?? "{}";
  const review = JSON.parse(text) as AIReviewResponse;

  return Response.json(review, {
    headers: {
      "Cache-Control": "no-store",
    },
  });
});
