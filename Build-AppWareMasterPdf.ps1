$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$outHtml = Join-Path $root "AppWare_Ecosystem_Master_Beautiful_PDF.html"
$outPdf = Join-Path $root "AppWare_Ecosystem_Master_Compendium.pdf"

function HtmlEncode([string]$value) {
  return [System.Net.WebUtility]::HtmlEncode($value)
}

function ReadDoc([string]$relativePath) {
  $path = Join-Path $root $relativePath
  if (Test-Path -LiteralPath $path) {
    return Get-Content -Raw -LiteralPath $path
  }
  return ""
}

function AssetUri([string]$relativePath) {
  $path = Join-Path $root $relativePath
  if (Test-Path -LiteralPath $path) {
    return ("file:///" + (($path -replace "\\", "/") -replace " ", "%20"))
  }
  return ""
}

function CleanText([string]$text) {
  if (-not $text) { return "" }
  return ($text -replace "[\x00-\x08\x0B\x0C\x0E-\x1F]", "")
}

function MdToReadableHtml([string]$text) {
  $text = CleanText $text
  $lines = $text -split "`r?`n"
  $html = New-Object System.Collections.Generic.List[string]
  $inList = $false
  $inTable = $false

  foreach ($raw in $lines) {
    $trim = $raw.Trim()
    if ($trim.Length -eq 0) {
      if ($inList) { $html.Add("</ul>"); $inList = $false }
      if ($inTable) { $html.Add("</table>"); $inTable = $false }
      continue
    }

    if ($trim -match '^```') { continue }
    if ($trim -match '^-{3,}$') { continue }
    if ($trim -match '^={3,}$') { continue }
    if ($trim -match '^<!--' -or $trim -match 'PROMPT_SUGGESTION' -or $trim -match '^-->') { continue }

    if ($trim -match '^\|(.+)\|$') {
      if ($trim -match '^\|\s*-+') { continue }
      if ($inList) { $html.Add("</ul>"); $inList = $false }
      if (-not $inTable) { $html.Add("<table>"); $inTable = $true }
      $cells = $trim.Trim("|").Split("|") | ForEach-Object { "<td>$((HtmlEncode $_.Trim()))</td>" }
      $html.Add("<tr>$($cells -join '')</tr>")
      continue
    } elseif ($inTable) {
      $html.Add("</table>")
      $inTable = $false
    }

    if ($trim -match '^(#{1,4})\s+(.+)$') {
      if ($inList) { $html.Add("</ul>"); $inList = $false }
      $level = [Math]::Min($matches[1].Length + 2, 5)
      $html.Add("<h$level>$((HtmlEncode $matches[2]))</h$level>")
      continue
    }

    if ($trim -match '^(\d+)\.\s+(.+)$') {
      if (-not $inList) { $html.Add("<ul class='detail-list'>"); $inList = $true }
      $html.Add("<li><b>$($matches[1]).</b> $((HtmlEncode $matches[2]))</li>")
      continue
    }

    if ($trim -match '^[-*]\s+(.+)$') {
      if (-not $inList) { $html.Add("<ul class='detail-list'>"); $inList = $true }
      $html.Add("<li>$((HtmlEncode $matches[1]))</li>")
      continue
    }

    if ($trim -match '^[A-Z0-9 ./'']{4,}:$') {
      if ($inList) { $html.Add("</ul>"); $inList = $false }
      $html.Add("<h4>$((HtmlEncode $trim.TrimEnd(':')))</h4>")
      continue
    }

    if ($inList) { $html.Add("</ul>"); $inList = $false }
    $html.Add("<p>$((HtmlEncode $trim))</p>")
  }

  if ($inList) { $html.Add("</ul>") }
  if ($inTable) { $html.Add("</table>") }
  return ($html -join "`n")
}

function DocSection([string]$id, [string]$title, [string]$kicker, [string]$text, [string]$logo = "") {
  $logoHtml = ""
  if ($logo) { $logoHtml = "<img class='section-logo' src='$logo' alt=''>" }
  return @"
<section class="doc-section" id="$id">
  <div class="section-head">
    <div>
      <p class="kicker">$kicker</p>
      <h2>$title</h2>
    </div>
    $logoHtml
  </div>
  <div class="detail-flow">
    $(MdToReadableHtml $text)
  </div>
</section>
"@
}

function Card([string]$title, [string]$body) {
  return "<article class='card'><h3>$(HtmlEncode $title)</h3><p>$(HtmlEncode $body)</p></article>"
}

$hungryLogo = AssetUri "Hungry\public\icon-192.png"
if (-not $hungryLogo) { $hungryLogo = AssetUri "Hungry\apple-touch-logo.png" }
$roomiesLogo = AssetUri "Roomies\roomies-app\public\icon-192.png"
$jukeboxLogo = AssetUri "Jukebox\assets\icon.png"

$business = ReadDoc "# AppWare Ecosystem Business & Tech.txt"
$ideas = ReadDoc "Ideas.txt"
$documentation = ReadDoc "Documentation.txt"
$ecosystem = ReadDoc "EcosystemFeatures.md"
$appChanges = ReadDoc "AppChanges.md"
$auth = (ReadDoc "AppWare Auth\Build.md") + "`n`n" + (ReadDoc "AppWare Auth\Workbook\FeatureStatus.md") + "`n`n" + (ReadDoc "AppWare Auth\Documentation.txt") + "`n`n" + (ReadDoc "AppWare Auth\Schema.md") + "`n`n" + (ReadDoc "AppWare Auth\Changes.md")
$hungry = (ReadDoc "Hungry\Workbook\FeatureStatus.md") + "`n`n" + (ReadDoc "Hungry\Workbook\Changes.md") + "`n`n" + (ReadDoc "Hungry\Workbook\Onboarding.md") + "`n`n" + (ReadDoc "Hungry\Workbook\Problems.txt") + "`n`n" + (ReadDoc "Hungry\notes.txt")
$roomies = (ReadDoc "Roomies\Build.md") + "`n`n" + (ReadDoc "Roomies\STATUS.md") + "`n`n" + (ReadDoc "Roomies\Tutorial.md") + "`n`n" + (ReadDoc "Roomies\roomies-app\Workbook\Changes.md") + "`n`n" + (ReadDoc "Roomies\roomies-app\README.md")
$jukebox = (ReadDoc "Jukebox\Build\Build.md") + "`n`n" + (ReadDoc "Jukebox\Workbook\FeatureStatus.md") + "`n`n" + (ReadDoc "Jukebox\NewUI.md") + "`n`n" + (ReadDoc "Jukebox\OnboardingTutorial.md") + "`n`n" + (ReadDoc "Jukebox\Workbook\Ideas.txt") + "`n`n" + (ReadDoc "Jukebox\Workbook\Problems.txt") + "`n`n" + (ReadDoc "Jukebox\Workbook\Changes.md")
$sql = ReadDoc "appware_unified_schema.sql"

$coverLogoRow = @"
<div class="app-logo-row">
  <div><img src="$hungryLogo" alt=""><span>Hungry</span></div>
  <div><img src="$roomiesLogo" alt=""><span>Roomies</span></div>
  <div><img src="$jukeboxLogo" alt=""><span>Jukebox</span></div>
</div>
"@

$executiveCards = @(
  Card "The product" "A connected suite for shared households: food intelligence, domestic operations, and social atmosphere tied together by one AppWare identity."
  Card "The moat" "Shared household context. The system knows who lives together, what they eat, what they owe, what needs doing, what music shapes the space, and what moments are worth remembering."
  Card "The launch wedge" "Roomies creates the invite loop, Hungry creates daily utility, Jukebox creates emotional and social stickiness, and AppWare Auth makes it all one account."
  Card "The long-term prize" "The AI House Manager: a daily briefing and action layer that coordinates meals, chores, budgets, events, groceries, pets, music, and household mood."
) -join "`n"

$futureIdeas = @"
## Core Future Features
- AI Household Assistant: uses fridge expiry, chore delays, household mood, budget status, and music context to suggest coordinated actions.
- Roommate Compatibility Score: compares cleaning habits, music tastes, cooking frequency, and sleep schedules before people move in together.
- House Party Mode: shared playlist voting, snack inventory tracking, automatic split costs, and guest QR join.
- AI Grocery Predictor: learns household consumption cycles and builds shopping lists before users notice they are out.
- Formalized Magic Moments: first 100% chore completion, 50th meal cooked together, one-year living together, and 100 hours of music shared become shareable cards, reels, and stories.
- Landlord Edition: rent tracking, maintenance requests, household analytics, and per-unit property manager pricing.
- AI Meal Budget Mode: budget, household size, grocery list, recipes, cost breakdown, and expense split in one workflow.
- House Personalities: monthly classifications based on food, chores, music, takeout, and household behavior.
- Chore Draft Night: Sunday fantasy-football-style chore claiming.
- Spotify Wrapped for Houses: most played artist, most cooked meal, biggest spender, most reliable roommate, most forgotten chore, and household MVP.
- AI Fridge Detective: photo-based meal potential and funny pantry diagnosis.
- Household Lore: automatic timeline of first meals, grocery trips, expensive receipts, chore streaks, and memorable crises.
- House Pet Integration: feeding, walking, vet appointments, and pet expenses.
- Real-Life Achievements: finals survived, first apartment together, zero food waste month, no chore arguments, and rent paid early streaks.
- Relationship Mode: couples, engaged couples, newlyweds, shared groceries, shared budgets, date night planning, and relationship milestones.

## EDU Mode
- Finals Week Mode: lower chore expectations, critical chores only, study room reservations, quick meals, budget meals, meal prep, focus playlists, study sessions, and Pomodoro music.
- Shared Food Economy: Shared, Mine, Ask First, and Hands Off food labels.
- Broke Student Mode: weekly budget, dining hall swipes, grocery budget, and AI survival meal plans.
- Campus Specials Feed: cheap food deals, happy hours, club events, and free food.
- Campus Survival Alerts: dining hall closing, campus bus delays, and high-value student alerts.
- Semester Wrapped: coffees, meals cooked, all-nighters, songs played, and grocery savings.
- GPA Protection Mode: exam/deadline input, notification reduction, simple meal suggestions, and temporary chore suspension.
- Move-In Week Assistant: mattress topper, cleaning supplies, microwave, mini fridge, extension cords, and split purchases.
- Student Marketplace: verified student trading for textbooks, furniture, mini-fridges, TVs, and air fryers.
"@

$rollout = @"
## Rollout Ideas
- Ambassador Program: 5-10 campus founders per school, free AppWare Plus, exclusive badge, early access, and lifetime Plus for bringing 25 students.
- Launch By School: NC State rollout, then UNC, then ECU; create scarcity instead of launching everywhere.
- Move-In Week Blitz: August move-in survival kit, apartment checklist, budget planner, roommate agreement template, and email collection.
- Founding Household Status: first 100 households receive permanent badge, special theme, and lifetime discount.
- Market Waves: roommates first, couples second, families third, communities fourth.
- Product-Led Referral Loops: Meal Analytics requires household members, House Karma needs 3 members, shared listening rooms invite friends.
- Seasonal Launches: Cookout Mode, Football Saturdays, Holiday House Mode, and Deep Clean Challenge.
- Outcome-Based Marketing: lead with savings, meals cooked, and fewer chore arguments rather than listing app categories.
- AI Household Awards: Chef of the Month, Budget Master, Chore Hero, DJ of the Month, and Most Improved.
"@

$monetization = @"
## Monetization Ideas
- Household Subscription: 9.99 per household for up to 6 roommates.
- Student Plus: 2.99/month for unlimited AI, Semester Wrapped, campus rankings, and premium themes.
- House Plus: 14.99/month for everyone premium, shared AI assistant, shared reports, and premium leaderboards.
- Grocery Cashback: Hungry builds grocery carts through Instacart, Walmart, Target, or similar partners.
- Restaurant Partnerships: when ingredients are unavailable, suggest local pizza/taco deals and take referral revenue.
- Campus Business Marketplace: apartment complexes, gyms, barbers, and tutors pay for offers.
- Premium AppWare Wrap: animated video, more stats, custom themes, and AI household story for a one-time purchase.
- Custom House Themes: Y2K, Vaporwave, College Football, Retro Dorm, and similar paid themes.
- Digital Collectibles: Spring 2027 Founder, 100 Chore Streak, Top House, and status badges.
- AI Premium Features: AI Roommate Advisor, AI Budget Coach, AI Meal Planner, and unlimited generation tiers.
- Family Tier: shared groceries, chore tracking for kids, allowance, and family meal planning.
- Wedding and Moving Kits: Moving In Together Pack, Newlywed Pack, budget templates, setup checklists, and shared inventory.
- Local Commerce Layer: grocery stores, cleaning services, meal kits, and household supply referrals.
- Premium AI Household Manager: daily briefing subscription for milk, rent, cleaning, and dinner recommendations.
- Enterprise / Property Manager Edition: maintenance, shared spaces, resident communication, community events, and large-account onboarding.
"@

$html = @"
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <title>AppWare Ecosystem Master Plan</title>
  <style>
    @page { size: Letter; margin: .46in; }
    * { box-sizing: border-box; }
    body { margin: 0; color: #1d2738; background: #f3f6fa; font-family: Inter, "Segoe UI", Arial, sans-serif; line-height: 1.46; }
    .cover { min-height: 9.95in; page-break-after: always; padding: .55in; color: white; display: flex; flex-direction: column; justify-content: space-between; background: linear-gradient(132deg, rgba(8,16,31,.94), rgba(25,45,76,.9)), radial-gradient(circle at 18% 18%, rgba(110,200,255,.55), transparent 28%), radial-gradient(circle at 90% 78%, rgba(255,176,98,.42), transparent 34%); }
    .cover h1 { margin: 0; max-width: 8.15in; font-size: 55px; line-height: .98; letter-spacing: 0; }
    .cover p { max-width: 7.1in; color: rgba(255,255,255,.76); font-size: 18px; }
    .eyebrow, .kicker { margin: 0 0 10px; color: #62728b; font-size: 10px; font-weight: 900; letter-spacing: .16em; text-transform: uppercase; }
    .cover .eyebrow { color: rgba(255,255,255,.58); }
    .app-logo-row { display: flex; gap: 14px; align-items: center; }
    .app-logo-row div { display: flex; align-items: center; gap: 8px; padding: 8px 12px; border-radius: 18px; background: rgba(255,255,255,.12); border: 1px solid rgba(255,255,255,.22); }
    .app-logo-row img { width: 34px; height: 34px; border-radius: 9px; object-fit: cover; }
    .app-logo-row span { font-size: 12px; font-weight: 900; color: white; }
    .cover-grid { display: grid; grid-template-columns: repeat(4, 1fr); gap: 11px; }
    .cover-grid div { min-height: 92px; padding: 14px; border-radius: 18px; background: rgba(255,255,255,.12); border: 1px solid rgba(255,255,255,.22); }
    .cover-grid b { display: block; margin-bottom: 6px; color: white; font-size: 13px; }
    .cover-grid span { color: rgba(255,255,255,.68); font-size: 11px; }
    .hero { page-break-after: always; padding: .28in 0; }
    .doc-section { page-break-before: always; padding: 0 0 .12in; }
    .section-head { display: flex; align-items: center; justify-content: space-between; gap: 20px; padding-bottom: 14px; margin-bottom: 18px; border-bottom: 1px solid rgba(80,98,124,.18); }
    h2 { margin: 0; color: #142035; font-size: 28px; line-height: 1.08; letter-spacing: 0; }
    h3 { margin: 18px 0 8px; color: #172238; font-size: 18px; line-height: 1.18; break-after: avoid; }
    h4 { margin: 14px 0 7px; color: #26354a; font-size: 13px; text-transform: uppercase; letter-spacing: .08em; break-after: avoid; }
    p { margin: 0 0 8px; color: #45556b; font-size: 12.2px; }
    .section-logo { width: 56px; height: 56px; border-radius: 15px; object-fit: cover; box-shadow: 0 12px 26px rgba(25,44,70,.16); }
    .hero-panel { padding: 22px; border-radius: 26px; color: white; background: linear-gradient(145deg, #17243c, #255077); box-shadow: 0 18px 42px rgba(34,58,91,.17); }
    .hero-panel h3 { margin-top: 0; color: white; }
    .hero-panel p { color: rgba(255,255,255,.76); font-size: 14px; }
    .cards { display: grid; gap: 12px; margin: 14px 0; }
    .cards.two { grid-template-columns: repeat(2, 1fr); }
    .card, .detail-list li, table { border-radius: 15px; background: rgba(255,255,255,.82); border: 1px solid rgba(79,101,130,.15); box-shadow: 0 10px 26px rgba(45,69,103,.07); }
    .card { padding: 15px; break-inside: avoid; }
    .card h3 { margin-top: 0; font-size: 15px; }
    .card p { margin-bottom: 0; }
    .detail-flow { column-count: 2; column-gap: 18px; }
    .detail-flow h3, .detail-flow h4, .detail-flow table { column-span: all; }
    .detail-list { list-style: none; padding: 0; margin: 8px 0 12px; }
    .detail-list li { padding: 8px 10px; margin: 6px 0; color: #415267; font-size: 10.8px; break-inside: avoid; }
    table { width: 100%; margin: 8px 0 14px; border-collapse: separate; border-spacing: 0; overflow: hidden; break-inside: avoid; }
    td { padding: 7px 8px; border-bottom: 1px solid rgba(79,101,130,.13); color: #405066; font-size: 10.3px; vertical-align: top; }
    tr:first-child td { color: #172238; font-weight: 900; background: rgba(33,118,255,.08); }
    code { padding: 1px 5px; border-radius: 6px; background: rgba(29,54,83,.08); color: #183b62; font-family: Consolas, monospace; }
    .footer-note { margin-top: 16px; padding-top: 10px; border-top: 1px solid rgba(80,98,124,.18); color: #7b8798; font-size: 10px; }
  </style>
</head>
<body>
  <section class="cover">
    <div>
      <p class="eyebrow">AppWare Ecosystem Master Plan</p>
      $coverLogoRow
    </div>
    <div>
      <h1>Every App, Every Feature, Every Idea, Rebuilt as a Readable Product PDF</h1>
      <p>This version ignores the Grand Compendium and turns the actual workspace notes into a structured, polished, detailed reference for AppWare Auth, Hungry, Roomies, Jukebox, the unified build process, future feature ideas, rollout strategy, and monetization.</p>
    </div>
    <div class="cover-grid">
      <div><b>Identity</b><span>AppWare Auth, shared Supabase accounts, universal profiles, friends, and redirect-based SSO.</span></div>
      <div><b>Household</b><span>Households, household members, active household, RLS, and shared domestic context.</span></div>
      <div><b>Signal Bus</b><span>Cross-app events connect cooking, chores, groceries, music, budgets, and mood.</span></div>
      <div><b>Growth</b><span>Campus rollout, move-in week, referrals, paid tiers, enterprise, and commerce.</span></div>
    </div>
  </section>

  <section class="hero">
    <div class="section-head"><div><p class="kicker">Executive Layer</p><h2>What AppWare Is</h2></div></div>
    <div class="hero-panel"><h3>A connected living system, not a pile of apps.</h3><p>AppWare combines a kitchen intelligence app, a household operations app, a music-social atmosphere app, and a shared auth portal into a single user and household graph. The core strategy is to make daily shared-living friction visible, solvable, and emotionally memorable.</p></div>
    <div class="cards two">$executiveCards</div>
  </section>

  $(DocSection "business" "Business and Technical Master Plan" "Strategy, monetization, integrated features, and 500 MAU path" $business)
  $(DocSection "ecosystem" "Cross-App Ecosystem Features" "Signal-bus features and technical integration notes" $ecosystem)
  $(DocSection "build" "Entire Build Process" "What was built, schema decisions, migrations, blockers, and setup checklist" $documentation)
  $(DocSection "changes" "App Migration Notes" "Compatibility and code-change roadmap by app" $appChanges)
  $(DocSection "auth" "AppWare Auth Portal" "Authentication, SSO, friends, portal, schema, and deployment" $auth)
  $(DocSection "hungry" "Hungry: Kitchen, Pantry, Recipes, Events, and AI" "Complete shipped features, requested fixes, onboarding, blockers, and future work" $hungry $hungryLogo)
  $(DocSection "roomies" "Roomies: Household Operations and Co-Living System" "Product spec, schema, UI paradigm, algorithms, implementation directives, status, and tutorial" $roomies $roomiesLogo)
  $(DocSection "jukebox" "Jukebox: Music Social, Discovery, and Atmosphere" "Production spec, feature status, UI, onboarding, artist tools, integrations, and blockers" $jukebox $jukeboxLogo)
  $(DocSection "future" "All Future Feature Ideas" "Household AI, compatibility, parties, predictions, lore, pets, relationships, EDU mode, and more" ($futureIdeas + "`n`n" + $ideas))
  $(DocSection "rollout" "Rollout and Growth Plan" "Ambassadors, school launches, move-in blitz, referrals, seasons, and awards" $rollout)
  $(DocSection "monetization" "Monetization Plan" "Subscriptions, commerce, premium wraps, themes, collectibles, families, enterprise" $monetization)
  $(DocSection "sql" "Unified Supabase Schema Detail" "Tables, policies, realtime, triggers, and backend contract" $sql)

  <section class="doc-section">
    <div class="section-head"><div><p class="kicker">Source Control</p><h2>Generated From Workspace Files</h2></div></div>
    <p class="footer-note">Generated locally from the AppWare workspace on May 30, 2026. The Grand Compendium was intentionally excluded from this rebuild per instruction.</p>
  </section>
</body>
</html>
"@

Set-Content -LiteralPath $outHtml -Value $html -Encoding UTF8

$chrome = "C:\Program Files\Google\Chrome\Application\chrome.exe"
if (Test-Path -LiteralPath $chrome) {
  & $chrome --headless --disable-gpu --no-sandbox --print-to-pdf="$outPdf" "file:///$($outHtml -replace '\\','/' -replace ' ','%20')"
}

Write-Host $outHtml
Write-Host $outPdf
