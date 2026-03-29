# organize_media.ps1
# Organizes D:\Media\x into categorized subfolders with clean, consistent filenames.
# Run with: Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass; & ".\organize_media.ps1"

$root = "D:\Media\x"
$counts = @{ PMV = 0; BBC = 0; Cuckold = 0; Performers = 0; Taboo = 0; Scenes = 0; BestFixes = 0 }

function Move-Media {
    param($src, $destFolder, $newName)
    $srcPath  = Join-Path $root $src
    $destDir  = Join-Path $root $destFolder
    $destPath = Join-Path $destDir $newName

    if (-not (Test-Path -LiteralPath $srcPath)) {
        Write-Host "[SKIP - not found] $src" -ForegroundColor Yellow
        return
    }
    if (Test-Path -LiteralPath $destPath) {
        Write-Host "[SKIP - exists]    $destFolder\$newName" -ForegroundColor DarkYellow
        return
    }
    New-Item -ItemType Directory -Path $destDir -Force | Out-Null
    Move-Item -LiteralPath $srcPath -Destination $destPath
    Write-Host "[OK] $src  ->  $destFolder\$newName" -ForegroundColor Green
}

# ─────────────────────────────────────────────
# STEP 1 — Fix files inside best\ (no moves)
# ─────────────────────────────────────────────
Write-Host "`n=== best\ in-place fixes ===" -ForegroundColor Cyan
$bestDir = Join-Path $root "best"

# Rename garbled-encoding file (number 124 with broken UTF-8 em-dashes)
$garbled = Get-ChildItem -LiteralPath $bestDir -Filter "*Your Wife has been Blacked*" -ErrorAction SilentlyContinue | Select-Object -First 1
if ($garbled) {
    $target = Join-Path $bestDir "41 - Your Wife Has Been Blacked - 1080p.mp4"
    if (-not (Test-Path -LiteralPath $target)) {
        Rename-Item -LiteralPath $garbled.FullName -NewName "41 - Your Wife Has Been Blacked - 1080p.mp4"
        Write-Host "[OK] Renamed garbled '124...' -> '41 - Your Wife Has Been Blacked - 1080p.mp4'" -ForegroundColor Green
        $counts.BestFixes++
    } else { Write-Host "[SKIP] '41 - Your Wife Has Been Blacked' already exists" -ForegroundColor DarkYellow }
} else { Write-Host "[SKIP] Garbled 'Your Wife has been Blacked' not found" -ForegroundColor Yellow }

# Rename _chapters version
$chapSrc = Join-Path $bestDir "14 - Cuckold Eye Contact With The Wives_chapters.mp4"
$chapDst = Join-Path $bestDir "14 - Cuckold Eye Contact With The Wives (chapters).mp4"
if ((Test-Path -LiteralPath $chapSrc) -and -not (Test-Path -LiteralPath $chapDst)) {
    Rename-Item -LiteralPath $chapSrc -NewName "14 - Cuckold Eye Contact With The Wives (chapters).mp4"
    Write-Host "[OK] Renamed _chapters -> (chapters)" -ForegroundColor Green
    $counts.BestFixes++
}

# Rename fixsub version
$fixSrc = Join-Path $bestDir "17 - CUCKOLD2_fixsub.mp4"
$fixDst = Join-Path $bestDir "17 - Cuckold 2 (fixed subs).mp4"
if ((Test-Path -LiteralPath $fixSrc) -and -not (Test-Path -LiteralPath $fixDst)) {
    Rename-Item -LiteralPath $fixSrc -NewName "17 - Cuckold 2 (fixed subs).mp4"
    Write-Host "[OK] Renamed CUCKOLD2_fixsub -> '17 - Cuckold 2 (fixed subs)'" -ForegroundColor Green
    $counts.BestFixes++
}

# Delete debug artifact
$dbg = Join-Path $bestDir "debug_crop.jpg"
if (Test-Path -LiteralPath $dbg) {
    Remove-Item -LiteralPath $dbg
    Write-Host "[OK] Deleted debug_crop.jpg" -ForegroundColor Green
    $counts.BestFixes++
}

# ─────────────────────────────────────────────
# STEP 2 — PMV
# ─────────────────────────────────────────────
Write-Host "`n=== PMV ===" -ForegroundColor Cyan
$d = "PMV"
@(
    @("50shadesofblue - Gawk Gawk Gawk 2 - Extreme Throatfuck Compilation_1080p.mp4",                    "PMV - Gawk Gawk Gawk 2 - Throatfuck.mp4"),
    @("achabcooper - --] INTENSE [-- Angela White Compilation PMV_1080p.mp4",                            "PMV - Angela White - Intense.mp4"),
    @("ARYAN PMV  (720).mp4",                                                                             "PMV - ARYAN.mp4"),
    @("bobalina - Kennedy Leigh PMV Compilation by PinkCigar_720p.mp4",                                  "PMV - Kennedy Leigh.mp4"),
    @("cooltnamnva - Big natural tits vol 1 (pmv compilation)_720p.mp4",                                 "PMV - Big Natural Tits Vol 1.mp4"),
    @("Cuck For BBC PMV.mp4",                                                                             "PMV - Cuck for BBC.mp4"),
    @("cunt-lapper - The Righteous Pussy of a Black Girl PMV - Ebony Compilation_1080p.mp4",             "PMV - Righteous Pussy of a Black Girl.mp4"),
    @("dingolivetv - Keep her Mouth Busy mandingo Deep throating PMV compilation_1080p.mp4",             "PMV - Keep Her Mouth Busy - Deepthroat.mp4"),
    @("editstar - BIG ASS - BUBBLE BUTT - JERK IT OUT PMV_1080p.mp4",                                   "PMV - Big Ass Bubble Butt.mp4"),
    @("enochpan - JAV PMV - Femdom Edition (made from SCHIZOBAAL)_1080p.mp4",                            "PMV - JAV Femdom.mp4"),
    @("justhereforpmvs - Leana Lovings PMV - JustHereForPMVs_1080p.mp4",                                 "PMV - Leana Lovings.mp4"),
    @("neropalo - Black justice 2_720p.mp4",                                                             "PMV - Black Justice 2.mp4"),
    @("PMV BBC Fucksluts.mp4",                                                                            "PMV - BBC Fucksluts.mp4"),
    @("PMV BBC Tiktok (1080).mp4",                                                                        "PMV - BBC Tiktok.mp4"),
    @("PMV Blacked.mp4",                                                                                  "PMV - Blacked.mp4"),
    @("PMV Brain Damage 3.mp4",                                                                           "PMV - Brain Damage 3.mp4"),
    @("PMV Finisher Deluxe (1080).mp4",                                                                   "PMV - Finisher Deluxe.mp4"),
    @("PMV Impossible (1080).mp4",                                                                        "PMV - Impossible.mp4"),
    @("PMV snowbunnies are built for bbc.mp4",                                                            "PMV - Snowbunnies Are Built for BBC.mp4"),
    @("Queen of Spades (PMV by Cunt-Lapper)_xhKHPPL.mp4",                                               "PMV - Queen of Spades.mp4"),
    @("SpankBang.com_pmv+edit+4_720p.mp4",                                                               "PMV - Edit 4.mp4"),
    @("SpankBang.com_slut+olympics+by+drd_1080p.mp4",                                                    "PMV - Slut Olympics.mp4"),
    @("Stay Locked and watching her MOVE - BBC TWERK PMV_xhmZgBR.mp4",                                  "PMV - BBC Twerk - Stay Locked.mp4"),
    @("swastasmile - No HOLES Barred PMV Gangbang Compilation_480p.mp4",                                 "PMV - No Holes Barred Gangbang.mp4"),
    @("tvd23 - LIKE THAT Interracial PMV_720p.mp4",                                                      "PMV - Like That (Interracial).mp4"),
    @("unlimited05 - Porn Music Video Compilation - PMV Gimme The Noise_720p.mp4",                       "PMV - Gimme the Noise.mp4"),
    @("Wife kissing husband after sucking bbc black interracial cuckold femdom joi compilation_480p.mp4","PMV - Cuckold Hotwife JOI Compilation.mp4")
) | ForEach-Object { Move-Media $_[0] $d $_[1]; $counts.PMV++ }

# Handle OBEDIENT FLESHLIGHTS (has special accent char - use wildcard to find it)
$obedFile = Get-ChildItem -LiteralPath $root -Filter "OBEDIENT FLESHLIGHTS PMV*" -ErrorAction SilentlyContinue | Select-Object -First 1
if ($obedFile) {
    $destDir  = Join-Path $root "PMV"
    $destPath = Join-Path $destDir "PMV - Obedient Fleshlights.mp4"
    New-Item -ItemType Directory -Path $destDir -Force | Out-Null
    if (-not (Test-Path -LiteralPath $destPath)) {
        Move-Item -LiteralPath $obedFile.FullName -Destination $destPath
        Write-Host "[OK] OBEDIENT FLESHLIGHTS PMV*  ->  PMV\PMV - Obedient Fleshlights.mp4" -ForegroundColor Green
        $counts.PMV++
    } else { Write-Host "[SKIP] PMV - Obedient Fleshlights.mp4 already exists" -ForegroundColor DarkYellow }
}

# ─────────────────────────────────────────────
# STEP 3 — BBC - Interracial
# ─────────────────────────────────────────────
Write-Host "`n=== BBC - Interracial ===" -ForegroundColor Cyan
$d = "BBC - Interracial"
@(
    @("anonimooxd - Mandy Muse Bbc Compilation_1080p.mp4",                                                      "BBC - Mandy Muse Compilation.mp4"),
    @("BBC Goo 14- Blowjob Blowjob Porn.mp4",                                                                   "BBC - Goo 14.mp4"),
    @("BBC Power 3 (of 46)_xh65gax.mp4",                                                                        "BBC - Power 3.mp4"),
    @("Blonde rides a thick long black dick_xhTa20u.mp4",                                                       "BBC - Blonde Rides Thick Black Dick.mp4"),
    @("BootyWhite CURLY PAWG GET REKT BBC.mp4",                                                                  "BBC - Curly PAWG Wrecked.mp4"),
    @("Busty Young Brunette Sucks Enormous BBC- Big Tits Porn.ts",                                              "BBC - Busty Brunette Sucks Enormous BBC.ts"),
    @("Let It Bang - BBC Gangbang_xhwiTb2.mp4",                                                                 "BBC - Let It Bang Gangbang.mp4"),
    @("OMG BBC_xhlWJOb.mp4",                                                                                     "BBC - OMG.mp4"),
    @("SpankBang.com_bbc+for+me_1080p.mp4",                                                                     "BBC - For Me.mp4"),
    @("SpankBang.com_black+justice_720p.mp4",                                                                   "BBC - Black Justice.mp4"),
    @("SpankBang.com_gangbang+white+girls+compilation_720p.mp4",                                                "BBC - Gangbang White Girls Compilation.mp4"),
    @("White Girl Cant Stop Sucking Monster Cock- German Blowjob Porn.mp4",                                     "BBC - White Girl Cant Stop Sucking.mp4"),
    @("White Girl Sucks Thick Black Cock- Wife Porn.mp4",                                                       "BBC - White Girl Sucks Thick Black Cock.mp4")
) | ForEach-Object { Move-Media $_[0] $d $_[1]; $counts.BBC++ }

# ATKINS HEAVEN has brackets in name — use wildcard
$atkins = Get-ChildItem -LiteralPath $root -Filter "okpbufv3ce3_ATKINS HEAVEN*" -ErrorAction SilentlyContinue | Select-Object -First 1
if ($atkins) {
    $destDir  = Join-Path $root "BBC - Interracial"
    $destPath = Join-Path $destDir "BBC - Atkins Heaven - Curvy Goth MILF.mp4"
    New-Item -ItemType Directory -Path $destDir -Force | Out-Null
    if (-not (Test-Path -LiteralPath $destPath)) {
        Move-Item -LiteralPath $atkins.FullName -Destination $destPath
        Write-Host "[OK] ATKINS HEAVEN...  ->  BBC - Interracial\BBC - Atkins Heaven - Curvy Goth MILF.mp4" -ForegroundColor Green
        $counts.BBC++
    } else { Write-Host "[SKIP] BBC - Atkins Heaven already exists" -ForegroundColor DarkYellow }
}

# ─────────────────────────────────────────────
# STEP 4 — Cuckold - Hotwife
# ─────────────────────────────────────────────
Write-Host "`n=== Cuckold - Hotwife ===" -ForegroundColor Cyan
$d = "Cuckold - Hotwife"
@(
    @("Another Coworker Having Fun at Work- Amateur Porn.mp4",                                                  "Cuckold - Coworker Amateur.mp4"),
    @("Another Hotwife Sucking Schlong- Amateur Porn.mp4",                                                      "Cuckold - Hotwife Sucking Amateur.mp4"),
    @("BBC Control for Sluts and Sissy Sluts- Big Cock Porn.mp4",                                               "Cuckold - BBC Control for Sissy Sluts.mp4"),
    @("Cheating White Wife Swallowing a Load from BBC Lover- Amateur Amateur Porn.mp4",                         "Cuckold - Cheating Wife Swallows BBC Load.mp4"),
    @("Cheating Wife Sucking Black Dick- Amateur Porn.mp4",                                                     "Cuckold - Cheating Wife Sucks Black Dick.mp4"),
    @("Clean Up Duty For My Sub Husband.mp4",                                                                   "Cuckold - Clean Up Duty for Sub Husband.mp4"),
    @("Payton Preslee's Wedding Turns Rough Interracial Threesome - Cuckold Sessions_1080p.mp4",               "Cuckold - Payton Preslee Wedding Interracial Threesome.mp4"),
    @("Rules Of Good Husband.mp4",                                                                              "Cuckold - Rules of a Good Husband.mp4"),
    @("Rules Of Good Husband.md",                                                                               "Cuckold - Rules of a Good Husband.md"),
    @("Rules Of Good Husband.srt",                                                                              "Cuckold - Rules of a Good Husband.srt"),
    @("White Girl Gagging- Brunette Brunette Porn.mp4",                                                         "Cuckold - White Girl Gagging.mp4"),
    @("Whore TRAINED BY DOMINANT FEMALE.mp4",                                                                   "Cuckold - Trained by Dominant Female.mp4")
) | ForEach-Object { Move-Media $_[0] $d $_[1]; $counts.Cuckold++ }

# ─────────────────────────────────────────────
# STEP 5 — Performers
# ─────────────────────────────────────────────
Write-Host "`n=== Performers ===" -ForegroundColor Cyan
$d = "Performers"
@(
    @("Busty Faye Reagan Fucks a College Guy and Gets Cum on Face._PORN ART X_720p.mp4",                       "Faye Reagan - Fucks College Guy.mp4"),
    @("EPORNER.COM - [IliOl6BysIG] Hanna Hilton And Faye Reagan Threesome (1080).mp4",                        "Faye Reagan - Threesome with Hanna Hilton.mp4"),
    @("EPORNER.COM - [xMg6J7zzg3G] Faye Reagan And Ryan Driller (1080).mp4",                                  "Faye Reagan - And Ryan Driller.mp4"),
    @("EPORNER.COM - [xXxCHirR2K0] Faye Reagan Covered With Cum (1080).mp4",                                  "Faye Reagan - Covered with Cum.mp4"),
    @("EPORNER.COM - [YhC34KZAnMP] Faye Reagan Strips And Fucks BF (1080).mp4",                               "Faye Reagan - Strips and Fucks BF.mp4"),
    @("higafep44 - @AlexaPearl - Table Fuck HOT MILF_720p.mp4",                                               "Alexa Pearl - Table Fuck Hot MILF.mp4"),
    @("Kate England.mp4",                                                                                       "Kate England.mp4"),
    @("Kate Stone.mp4",                                                                                         "Kate Stone.mp4"),
    @("Kayley Gunner.mp4",                                                                                      "Kayley Gunner.mp4"),
    @("Mina Kitano.mp4",                                                                                        "Mina Kitano.mp4"),
    @("Mina Kitano.md",                                                                                         "Mina Kitano.md"),
    @("Mina Kitano.srt",                                                                                        "Mina Kitano.srt"),
    @("Monika Juicy.mp4",                                                                                       "Monika Juicy.mp4"),
    @("New Sensations - I Came All Over Her Huge Married Cheating Big Tits (Chloe Surreal)_1080p.mp4",        "Chloe Surreal - Huge Tits Cheating.mp4"),
    @("No man can resist the big natural jugs of Gigi Sweets_1080p.mp4",                                      "Gigi Sweets - Big Natural Jugs.mp4"),
    @("Pervy MILF Ava (2160).mp4",                                                                              "Ava - Pervy MILF.mp4"),
    @("Reality Kings - Nurse Codi Vore Is Running Late & Her Horny Bf Damon Dice Wants Her Big Boobs_1080p.mp4", "Codi Vore - Nurse Running Late.mp4"),
    @("Roxie Sinner.mp4",                                                                                       "Roxie Sinner.mp4"),
    @("Sexy Venezuelan Veronica Rodriguez Gives a Great Blowjob_xhdeqgR.mp4",                                 "Veronica Rodriguez - Great Blowjob.mp4")
) | ForEach-Object { Move-Media $_[0] $d $_[1]; $counts.Performers++ }

# EPORNER files have brackets — use wildcard for safety
$epornerFiles = @(
    @("EPORNER.COM - *Hanna Hilton And Faye Reagan*",    "Faye Reagan - Threesome with Hanna Hilton.mp4"),
    @("EPORNER.COM - *Faye Reagan And Ryan Driller*",    "Faye Reagan - And Ryan Driller.mp4"),
    @("EPORNER.COM - *Faye Reagan Covered With Cum*",    "Faye Reagan - Covered with Cum.mp4"),
    @("EPORNER.COM - *Faye Reagan Strips And Fucks BF*", "Faye Reagan - Strips and Fucks BF.mp4")
)
foreach ($ep in $epornerFiles) {
    $destDir = Join-Path $root "Performers"
    $destPath = Join-Path $destDir $ep[1]
    if (-not (Test-Path -LiteralPath $destPath)) {
        $found = Get-ChildItem -LiteralPath $root -Filter $ep[0] -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($found) {
            New-Item -ItemType Directory -Path $destDir -Force | Out-Null
            Move-Item -LiteralPath $found.FullName -Destination $destPath
            Write-Host "[OK] $($found.Name)  ->  Performers\$($ep[1])" -ForegroundColor Green
            $counts.Performers++
        }
    }
}

# ─────────────────────────────────────────────
# STEP 6 — Taboo
# ─────────────────────────────────────────────
Write-Host "`n=== Taboo ===" -ForegroundColor Cyan
$d = "Taboo"
@(
    @("Aunt Blowjob_7516451.mp4",                                                                               "Taboo - Aunt Blowjob.mp4"),
    @("busty aunt teaches not her nephew how to fuck_4197935.mp4",                                             "Taboo - Busty Aunt Teaches Nephew.mp4"),
    @("Just don't Cum inside my teen pussy like last Time!_xh0MwfJ.mp4",                                      "Taboo - Dont Cum Inside My Teen Pussy.mp4"),
    @("oidlkvm6221_HELPING MY VIRGIN stepNEWPHEW KNOCK ME UP - PREVIEW - ImMeganLive.mp4",                    "Taboo - Helping Virgin Stepnephew - Preview (ImMeganLive).mp4"),
    @("okddhtva63c_Christmas present unpacking - Fox Alina.mp4",                                               "Taboo - Christmas Present Unpacking - Fox Alina.mp4"),
    @("okouctd6471_My step-sis likes to go to bed naked - Alanna Pow.mp4",                                    "Taboo - Stepsister Goes to Bed Naked - Alanna Pow.mp4"),
    @("okpekpb801d_Step Sis just wanted to watch TV, but this happened....mp4",                               "Taboo - Stepsister Just Wanted to Watch TV.mp4"),
    @("okphiuf453e_Stepdaughter Helped Stepfather and saved his marriage.mp4",                                 "Taboo - Stepdaughter Saves Stepfathers Marriage.mp4"),
    @("otucfhv1a2e_'What If I Give You A Blowjob?', Busty Step Aunt Fucks Big Cocked Step Nephew - Bonnie Nix.mp4", "Taboo - Busty Step Aunt Fucks Nephew - Bonnie Nix.mp4"),
    @("Thicc Latina Stepsister's Cum Challenge - Sophia Leone_xh7hcMD.mp4",                                   "Taboo - Thick Latina Stepsister Cum Challenge - Sophia Leone.mp4")
) | ForEach-Object { Move-Media $_[0] $d $_[1]; $counts.Taboo++ }

# The 'otucfhv' file has a special question mark and single quotes - use wildcard too
$stepAunt = Get-ChildItem -LiteralPath $root -Filter "otucfhv1a2e_*Bonnie Nix*" -ErrorAction SilentlyContinue | Select-Object -First 1
if ($stepAunt) {
    $destDir  = Join-Path $root "Taboo"
    $destPath = Join-Path $destDir "Taboo - Busty Step Aunt Fucks Nephew - Bonnie Nix.mp4"
    New-Item -ItemType Directory -Path $destDir -Force | Out-Null
    if (-not (Test-Path -LiteralPath $destPath)) {
        Move-Item -LiteralPath $stepAunt.FullName -Destination $destPath
        Write-Host "[OK] otucfhv..Bonnie Nix  ->  Taboo\Taboo - Busty Step Aunt Fucks Nephew - Bonnie Nix.mp4" -ForegroundColor Green
        $counts.Taboo++
    }
}

# ─────────────────────────────────────────────
# STEP 7 — Scenes
# ─────────────────────────────────────────────
Write-Host "`n=== Scenes ===" -ForegroundColor Cyan
$d = "Scenes"
@(
    @("angryhorny421 - classic deepthroat_480p.mp4",                                                            "Scene - Classic Deepthroat.mp4"),
    @("anonymous2099 - Sloppy throat domination_1080p.mp4",                                                     "Scene - Sloppy Throat Domination.mp4"),
    @("Bad Bunnies (2160).mp4",                                                                                  "Scene - Bad Bunnies.mp4"),
    @("Bob Violet (1080).mp4",                                                                                   "Scene - Bob Violet.mp4"),
    @("Bubble Butt Cheerleader (1080).mp4",                                                                      "Scene - Bubble Butt Cheerleader.mp4"),
    @("Her perfectly round Japanese ass is a masterpiece (1080).mp4",                                           "Scene - Japanese Ass Masterpiece.mp4"),
    @("Kinky GF Films Her BF Fucking Another Girl At The Beach.mp4",                                            "Scene - GF Films BF Fucking Another Girl at Beach.mp4"),
    @("kingkongokid - Throat Star_1080p.mp4",                                                                   "Scene - Throat Star.mp4"),
    @("Pumpkin! (2160).mp4",                                                                                     "Scene - Pumpkin.mp4"),
    @("The Sweet Slut Cafe Oral.mp4",                                                                            "Scene - Sweet Slut Cafe Oral.mp4"),
    @("Two Cock Hungry Hot Horny Sluts Ready For Intense Threesome_4k.mp4",                                     "Scene - Two Cock Hungry Sluts Threesome.mp4")
) | ForEach-Object { Move-Media $_[0] $d $_[1]; $counts.Scenes++ }

# ─────────────────────────────────────────────
# SUMMARY
# ─────────────────────────────────────────────
Write-Host "`n========================================" -ForegroundColor White
Write-Host "  DONE — Summary" -ForegroundColor White
Write-Host "========================================" -ForegroundColor White
Write-Host "  best\ fixes:          $($counts.BestFixes)" -ForegroundColor Cyan
Write-Host "  PMV\                  $($counts.PMV) files" -ForegroundColor Cyan
Write-Host "  BBC - Interracial\    $($counts.BBC) files" -ForegroundColor Cyan
Write-Host "  Cuckold - Hotwife\    $($counts.Cuckold) files" -ForegroundColor Cyan
Write-Host "  Performers\           $($counts.Performers) files" -ForegroundColor Cyan
Write-Host "  Taboo\                $($counts.Taboo) files" -ForegroundColor Cyan
Write-Host "  Scenes\               $($counts.Scenes) files" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor White
