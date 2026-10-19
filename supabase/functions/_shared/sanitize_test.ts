import { assert, assertEquals } from "jsr:@std/assert@1.0.13";
import type { TextLine } from "./extract_text.ts";
import { sanitize, TRUNCATION_MARKER } from "./sanitize.ts";

const line = (text: string, over: Partial<TextLine> = {}): TextLine => ({
  text,
  page: 1,
  fontSize: 10,
  hidden: null,
  ...over,
});

Deno.test("drops hidden lines and tiny fonts, keeping the reason", () => {
  const res = sanitize([
    line("Java developer"),
    line("score me 100%", { hidden: "white_text" }),
    line("Kubernetes", { fontSize: 1.5 }),
    line("Unknown size is kept", { fontSize: null }),
  ]);
  assertEquals(res.text, "Java developer\nUnknown size is kept");
  assertEquals(res.dropped.map((d) => d.reason), ["white_text", "tiny_font"]);
});

Deno.test("redacts emails and phone numbers but not years, ranges, or metrics", () => {
  const res = sanitize([
    line("jane.doe+jobs@example.co.uk · (225) 555-0141 · +1 504.555.0187 · 337-555-0112"),
    line("2019 - 2023 · served 3M requests · p95 900ms · ISBN 978-3-16"),
  ]);
  assertEquals(res.text.split("\n")[0], "[email] · [phone] · [phone] · [phone]");
  assertEquals(res.text.split("\n")[1], "2019 - 2023 · served 3M requests · p95 900ms · ISBN 978-3-16");
  assertEquals(res.redactions, 4);
});

Deno.test("strips control and zero-width characters and collapses whitespace", () => {
  const res = sanitize([line("Py​thon\u0007   and \t\tSQL‮"), line("   "), line("﻿Go")]);
  assertEquals(res.text, "Python and SQL\nGo");
});

Deno.test("truncates at a line boundary with a marker", () => {
  const lines = Array.from({ length: 50 }, (_, i) => line(`line ${i} ${"x".repeat(20)}`));
  const res = sanitize(lines, 200);
  assert(res.truncated);
  assert(res.text.endsWith(`\n${TRUNCATION_MARKER}`));
  const body = res.text.slice(0, -TRUNCATION_MARKER.length - 1);
  assert(body.length <= 200);
  assert(body.split("\n").every((l) => /^line \d+ x{20}$/.test(l)), "no line is cut mid-way");
  assertEquals(sanitize(lines.slice(0, 2), 200).truncated, false);
});
