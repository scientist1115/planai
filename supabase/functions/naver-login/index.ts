// 네이버 로그인 → Supabase 세션 연결
// 앱이 받은 네이버 access token을 네이버에 확인하고, 같은 이메일의 Supabase 계정에 일회용 로그인 토큰을 발급한다.
// 배포: supabase functions deploy naver-login --no-verify-jwt
import { createClient } from "npm:@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};
const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { ...cors, "Content-Type": "application/json" } });

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  try {
    const { access_token } = await req.json();
    if (!access_token) return json({ error: "토큰이 없어요" }, 400);

    const me = await fetch("https://openapi.naver.com/v1/nid/me", {
      headers: { Authorization: `Bearer ${access_token}` },
    }).then((r) => r.json());
    if (me.resultcode !== "00") return json({ error: "네이버 인증에 실패했어요" }, 401);

    const email: string | undefined = me.response?.email;
    if (!email) return json({ error: "네이버 로그인 때 이메일 제공에 동의해 주세요" }, 400);

    const admin = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
    const { error: createErr } = await admin.auth.admin.createUser({
      email,
      email_confirm: true,
      user_metadata: { provider: "naver", naver_id: me.response.id, name: me.response.nickname ?? me.response.name },
    });
    if (createErr && !/already|registered|exists/i.test(createErr.message)) throw createErr;

    const { data, error } = await admin.auth.admin.generateLink({ type: "magiclink", email });
    if (error) throw error;
    return json({ token_hash: data.properties.hashed_token });
  } catch (e) {
    console.error(e);
    return json({ error: String(e) }, 500);
  }
});
