-- Remove USFM section headings stuck onto scripture examples (#32 follow-up).
--
-- At import, heading lines from the USFM (\s, \s1, \sp, \d) between two
-- verses were glued onto the verse before them, so an example ends with the
-- next section's title ("... dauha ela. Tore-isi-lou herevadia"), a Psalm 119
-- letter ("MEM"), or carries a Song of Songs speaker label ("Beloved",
-- "Lover", "Friends") in the middle.
--
-- The heading texts come from files/bible_data/{english,motu}/*.usfm, taken
-- per verse. Each row below had a heading removed only where that made the
-- example a contiguous run of its verse's words again. Every other example
-- already passed that check, apart from three verses WEB keeps only as a
-- footnote and 1CH 29:7 ("golddarikidia"), which have no heading. Five Motu lines that the USFM mislabels as \s1
-- (poetry in ISA 21:5, 29:16, 34:10, 64:11 and the end of MRK 12:19) are verse
-- text and were kept.
--
-- This is per verse, not a text rule, so it is a reviewed list rather than a
-- change to clean_scripture_text(). Each fix applies only while the old value
-- is still there, so re-running it, or running it after someone edited the
-- example, changes nothing.

-- Text cleanup, not an edit: pause the updated_at trigger.
ALTER TABLE public.words DISABLE TRIGGER update_words_updated_at;

-- --- example_motu (428 rows) ---

WITH fixes(id, old_value, new_value) AS (
  VALUES
    -- 1CH 1:4: Noa garana
    ('bfc96f1c-03cd-4fbb-bee5-c76262760303'::uuid, $h$Noa, Sem, Ham, Iaet. Noa garana$h$,
     $h$Noa, Sem, Ham, Iaet.$h$),
    -- 1CH 4:23: Simeon garana
    ('7cf5abf1-3306-4414-88cc-264dc8dab865'::uuid, $h$Unu na uro ikaradia taudia, bona Netaimi ai bona Gedera ai e nohova taudia; unuseni ai hanua pavapavana ida e nohova, iena ḡaukara ikaradia totona. Simeon garana$h$,
     $h$Unu na uro ikaradia taudia, bona Netaimi ai bona Gedera ai e nohova taudia; unuseni ai hanua pavapavana ida e nohova, iena ḡaukara ikaradia totona.$h$),
    -- 1CH 5:17: Iduhu ma bona iduhu-kahana sivaraidia
    ('05a92e52-8feb-428b-bbaf-2b38eec90a05'::uuid, $h$Ini iboudiai na Iotam, Iuda pavapavana, bona Ieroboam, Israel pavapavana, negadia ai edia uru ta ta ladadia ai e tore. Iduhu ma bona iduhu-kahana sivaraidia$h$,
     $h$Ini iboudiai na Iotam, Iuda pavapavana, bona Ieroboam, Israel pavapavana, negadia ai edia uru ta ta ladadia ai e tore.$h$),
    -- 1CH 6:30: Ane-abi taudia
    ('a8634c97-bd62-40ec-b802-b709b7502965'::uuid, $h$Usa natuna na Simea; Simea natuna na Hagia, Hagia natuna na Asaia. Ane-abi taudia$h$,
     $h$Usa natuna na Simea; Simea natuna na Hagia, Hagia natuna na Asaia.$h$),
    -- 1CH 7:12: Napatali garana
    ('04d312f3-c0ae-4fd7-878f-c43ba2b6fc10'::uuid, $h$Supim bona Hupim na Iri natuna; Husim na Ahere natuna. Napatali garana$h$,
     $h$Supim bona Hupim na Iri natuna; Husim na Ahere natuna.$h$),
    -- 1CH 7:12: Napatali garana
    ('1bbf3fb5-f14a-417a-b35f-275d505b4eab'::uuid, $h$Supim bona Hupim na Iri natuna; Husim na Ahere natuna. Napatali garana$h$,
     $h$Supim bona Hupim na Iri natuna; Husim na Ahere natuna.$h$),
    -- 1CH 7:13: Manase garana
    ('1e2d6335-84bf-48d7-9690-23bb266a02f9'::uuid, $h$Napatali natuna: Iasiel, Guni, Iesere, Salumu; sinadia na Bilha. Manase garana$h$,
     $h$Napatali natuna: Iasiel, Guni, Iesere, Salumu; sinadia na Bilha.$h$),
    -- 1CH 7:19: Efraim garana
    ('5bc85d9c-0fcd-4a4d-9f68-453c2d888fdb'::uuid, $h$Semida natuna: Ahiana, Sekem, Likihi, Aniama. Efraim garana$h$,
     $h$Semida natuna: Ahiana, Sekem, Likihi, Aniama.$h$),
    -- 1CH 7:19: Efraim garana
    ('741c478b-1973-4a5a-95d6-49f89fa62fa0'::uuid, $h$Semida natuna: Ahiana, Sekem, Likihi, Aniama. Efraim garana$h$,
     $h$Semida natuna: Ahiana, Sekem, Likihi, Aniama.$h$),
    -- 1CH 7:19: Efraim garana
    ('de941593-b169-41f1-9830-26029c05c2b9'::uuid, $h$Semida natuna: Ahiana, Sekem, Likihi, Aniama. Efraim garana$h$,
     $h$Semida natuna: Ahiana, Sekem, Likihi, Aniama.$h$),
    -- 1CH 9:34: Saulo senena bona garana
    ('438fa50d-eab8-4b1e-a483-ec8dde63a611'::uuid, $h$Levi taudia edia iduhu kwaradia bunu; idia na hegunalai taudia, edia uru ta ta ai; idia danu Ierusalem ai e nohova. Saulo senena bona garana$h$,
     $h$Levi taudia edia iduhu kwaradia bunu; idia na hegunalai taudia, edia uru ta ta ai; idia danu Ierusalem ai e nohova.$h$),
    -- 1CH 14:7: David ese Filistia taudia e hadareredia
    ('732d1e40-1872-4a59-9105-4e8596f80973'::uuid, $h$Elisama, Beliada, Elifelete. David ese Filistia taudia e hadareredia$h$,
     $h$Elisama, Beliada, Elifelete.$h$),
    -- 1CH 16:6: David ena hahenamo anena
    ('220aa7e7-04cc-4f27-b860-c849ff057319'::uuid, $h$bona hahelaḡa taudia Benaia bona lahasiel na kibi bae hiriri loulou, Dirava ena taravatu mauana vairanai. David ena hahenamo anena$h$,
     $h$bona hahelaḡa taudia Benaia bona lahasiel na kibi bae hiriri loulou, Dirava ena taravatu mauana vairanai.$h$),
    -- 1CH 29:9: David ese Dirava e hanamoa
    ('b95a92d4-50a2-40ef-8723-fa5ed1777e19'::uuid, $h$Bena taunimanima na e moale, badina be vada e heni mai lalo-uradia ida; badina be idia ese mai lalodia idoidiai Iehova vada e henia dudukau. David, hanua pavapavana, danu e moale bada herea. David ese Dirava e hanamoa$h$,
     $h$Bena taunimanima na e moale, badina be vada e heni mai lalo-uradia ida; badina be idia ese mai lalodia idoidiai Iehova vada e henia dudukau. David, hanua pavapavana, danu e moale bada herea.$h$),
    -- 1CO 1:17: Satauro herevana
    ('1b83958e-63e1-46a6-9078-eae887099da1'::uuid, $h$Badina be Keriso ese e siaigu dia taunimanima ibapatisodia totona, a sivarai namo iharorolaina; bona dia aonega herevadia amo basina haroro, Keriso ena satauro na asi siahuna baine mia na garina. Satauro herevana$h$,
     $h$Badina be Keriso ese e siaigu dia taunimanima ibapatisodia totona, a sivarai namo iharorolaina; bona dia aonega herevadia amo basina haroro, Keriso ena satauro na asi siahuna baine mia na garina.$h$),
    -- 1CO 4:13: Do baina igomui ita
    ('391ef699-e70d-4f04-a657-c428d43f0519'::uuid, $h$ladamai e hadikamu, to a hamarumarudiamu. Tanobada taḡena ai bona ḡau iboudiai momodia ai vada e halaomaimu ema bona harihari. Do baina igomui ita$h$,
     $h$ladamai e hadikamu, to a hamarumarudiamu. Tanobada taḡena ai bona ḡau iboudiai momodia ai vada e halaomaimu ema bona harihari.$h$),
    -- 1CO 6:11: Basio lebulebu
    ('07095936-0116-4d86-8582-c54605d4ac4d'::uuid, $h$Umui haida danu gunaguna unuheto; to vada e hurimui, vada e hahelaḡamui, bena maoromui vada e gwaurai, Lohiabada Iesu Keriso ladana ai bona iseda Dirava Laumana ai. Basio lebulebu$h$,
     $h$Umui haida danu gunaguna unuheto; to vada e hurimui, vada e hahelaḡamui, bena maoromui vada e gwaurai, Lohiabada Iesu Keriso ladana ai bona iseda Dirava Laumana ai.$h$),
    -- 1CO 6:11: Basio lebulebu
    ('9db80852-6bfb-4c34-9371-873baa08f210'::uuid, $h$Umui haida danu gunaguna unuheto; to vada e hurimui, vada e hahelaḡamui, bena maoromui vada e gwaurai, Lohiabada Iesu Keriso ladana ai bona iseda Dirava Laumana ai. Basio lebulebu$h$,
     $h$Umui haida danu gunaguna unuheto; to vada e hurimui, vada e hahelaḡamui, bena maoromui vada e gwaurai, Lohiabada Iesu Keriso ladana ai bona iseda Dirava Laumana ai.$h$),
    -- 1CO 11:1: Eda toma diho
    ('000e3be3-9198-4f9f-8e07-c0c419834b9e'::uuid, $h$Lau ba haḡoigu, lau ese Keriso na haḡoiamu heḡereḡerena. Eda toma diho$h$,
     $h$Lau ba haḡoigu, lau ese Keriso na haḡoiamu heḡereḡerena.$h$),
    -- 1JN 2:17: Hereva koikoi bona hereva momokani
    ('1f8d4e42-09b9-4419-8960-3679d4b68db6'::uuid, $h$Tanobada na baine lao bubuni, mai ena heḡahusi ida, a Ddirava ena ura e karaiamu tauna na baine noho hanaihanai. Hereva koikoi bona hereva momokani$h$,
     $h$Tanobada na baine lao bubuni, mai ena heḡahusi ida, a Ddirava ena ura e karaiamu tauna na baine noho hanaihanai.$h$),
    -- 1KI 9:14: Solomon ena hesiai taudia
    ('c6a05ad9-0ed0-4a53-9359-9254da1ca7ee'::uuid, $h$Hirama ese gold talent sinahu-ta ruahui vada e siaidia guna, hanua pavapavana enai. Solomon ena hesiai taudia$h$,
     $h$Hirama ese gold talent sinahu-ta ruahui vada e siaidia guna, hanua pavapavana enai.$h$),
    -- 1KI 11:40: Solomon e mase
    ('fb980007-0ac2-4df8-828b-cebed268404a'::uuid, $h$Taunabunai, Solomon ese Ieroboam iala-masena dalana e tahua. A Ieroboam e tore isi, e heau, Aigupto ela, Sisaka, Aigupto pavapavana, dekenai; ia na Aigupto ai e nohova ela bona Solomon e mase. Solomon e mase$h$,
     $h$Taunabunai, Solomon ese Ieroboam iala-masena dalana e tahua. A Ieroboam e tore isi, e heau, Aigupto ela, Sisaka, Aigupto pavapavana, dekenai; ia na Aigupto ai e nohova ela bona Solomon e mase.$h$),
    -- 1KI 14:28: Rehoboam e mase
    ('186ddad7-aa25-4670-9c38-ffbbda7a4774'::uuid, $h$Bena hanua pavapavana na Iehova ena dubu ai e raka vareaiva negadia iboudiai, hegima taudia ese unu kesi e abidia kauva, ma e loulaidiava, edia hegima rumana ai e atodiava. Rehoboam e mase$h$,
     $h$Bena hanua pavapavana na Iehova ena dubu ai e raka vareaiva negadia iboudiai, hegima taudia ese unu kesi e abidia kauva, ma e loulaidiava, edia hegima rumana ai e atodiava.$h$),
    -- 1KI 14:28: Rehoboam e mase
    ('7247de0c-4610-4ef8-8a3d-da73d5d515a4'::uuid, $h$Bena hanua pavapavana na Iehova ena dubu ai e raka vareaiva negadia iboudiai, hegima taudia ese unu kesi e abidia kauva, ma e loulaidiava, edia hegima rumana ai e atodiava. Rehoboam e mase$h$,
     $h$Bena hanua pavapavana na Iehova ena dubu ai e raka vareaiva negadia iboudiai, hegima taudia ese unu kesi e abidia kauva, ma e loulaidiava, edia hegima rumana ai e atodiava.$h$),
    -- 1KI 14:28: Rehoboam e mase
    ('bfa64bd0-2a21-4a78-a438-e37bb65ffc2b'::uuid, $h$Bena hanua pavapavana na Iehova ena dubu ai e raka vareaiva negadia iboudiai, hegima taudia ese unu kesi e abidia kauva, ma e loulaidiava, edia hegima rumana ai e atodiava. Rehoboam e mase$h$,
     $h$Bena hanua pavapavana na Iehova ena dubu ai e raka vareaiva negadia iboudiai, hegima taudia ese unu kesi e abidia kauva, ma e loulaidiava, edia hegima rumana ai e atodiava.$h$),
    -- 1KI 15:8: King Asa
    ('a626f215-24ef-4e26-96cd-ef38567026b0'::uuid, $h$Bena Abiama na tubu tama dekediai e mahuta; David ena hanua ai e guria. Ia gabuna ai natuna Asa e lohia. King Asa$h$,
     $h$Bena Abiama na tubu tama dekediai e mahuta; David ena hanua ai e guria. Ia gabuna ai natuna Asa e lohia.$h$),
    -- 1KI 16:7: King Elaha
    ('59d45815-62a8-4af5-a09e-e83c84e6b745'::uuid, $h$Iehova ena hereva na peroveta tauna lehu Hanani ena amo ma e kau, Baasa mai ena iduhu taudia ida latadiai, ena kara dika iboudiai Iehova vairanai e karava ḡaudia ai, ia imana gaukaradia amo e habadua, Ieroboam ena iduhu ida vada e heḡereḡere bona e habuaia tari dainai. King Elaha$h$,
     $h$Iehova ena hereva na peroveta tauna lehu Hanani ena amo ma e kau, Baasa mai ena iduhu taudia ida latadiai, ena kara dika iboudiai Iehova vairanai e karava ḡaudia ai, ia imana gaukaradia amo e habadua, Ieroboam ena iduhu ida vada e heḡereḡere bona e habuaia tari dainai.$h$),
    -- 1KI 16:7: King Elaha
    ('f4122265-5a6f-45e0-8cf5-c8098548d1fd'::uuid, $h$Iehova ena hereva na peroveta tauna lehu Hanani ena amo ma e kau, Baasa mai ena iduhu taudia ida latadiai, ena kara dika iboudiai Iehova vairanai e karava ḡaudia ai, ia imana gaukaradia amo e habadua, Ieroboam ena iduhu ida vada e heḡereḡere bona e habuaia tari dainai. King Elaha$h$,
     $h$Iehova ena hereva na peroveta tauna lehu Hanani ena amo ma e kau, Baasa mai ena iduhu taudia ida latadiai, ena kara dika iboudiai Iehova vairanai e karava ḡaudia ai, ia imana gaukaradia amo e habadua, Ieroboam ena iduhu ida vada e heḡereḡere bona e habuaia tari dainai.$h$),
    -- 1KI 16:28: King Ahaba
    ('dacdbe6d-299e-4309-a989-9d5b693d0d40'::uuid, $h$Bena Omri na tubu tama dekediai e mahuta, Samaria ai e guria; bona natuna Ahaba ese ia gabuna ai e lohia. King Ahaba$h$,
     $h$Bena Omri na tubu tama dekediai e mahuta, Samaria ai e guria; bona natuna Ahaba ese ia gabuna ai e lohia.$h$),
    -- 1KI 17:7: Elia na Sarepata ai
    ('c40455a3-a9f9-4cb1-af2e-8f43be63b2f2'::uuid, $h$A nega taina vada ela, bena sinavai maraḡina e kororo, badina be medu na se dihova una tano ai. Elia na Sarepata ai$h$,
     $h$A nega taina vada ela, bena sinavai maraḡina e kororo, badina be medu na se dihova una tano ai.$h$),
    -- 1KI 19:18: Elia ese Elisaia e boiria
    ('547f43f6-ad35-4e05-9ad0-279b7c3c98cd'::uuid, $h$Ḡau tamona, taunimanima daha hitu do baina hamauridia Israel ai, tuidia asie hadai Baal vauranai asie igo diho bona ududia amo asie harahua taudia iboudiai. Elia ese Elisaia e boiria$h$,
     $h$Ḡau tamona, taunimanima daha hitu do baina hamauridia Israel ai, tuidia asie hadai Baal vauranai asie igo diho bona ududia amo asie harahua taudia iboudiai.$h$),
    -- 1KI 22:28: Ahaba na tuan ai e mase
    ('978a56e3-e57c-44b1-8436-452120cd9528'::uuid, $h$Bena Mikaia eto, Bema oi na maino ai ba lou mai, bena Iehova na lauegu amo vada se hereva. Ma eto, Taunimanima ibouboumui ai, a kamonai. Ahaba na tuan ai e mase$h$,
     $h$Bena Mikaia eto, Bema oi na maino ai ba lou mai, bena Iehova na lauegu amo vada se hereva. Ma eto, Taunimanima ibouboumui ai, a kamonai.$h$),
    -- 1KI 22:40: King Iehosafat
    ('d8ed82a8-6be4-4657-a81e-d8809324007e'::uuid, $h$Taunabunai Ahaba na tubu tama dekediai e mahuta; ia natuna Ahasia na ia gabuna ai e lohia. King Iehosafat$h$,
     $h$Taunabunai Ahaba na tubu tama dekediai e mahuta; ia natuna Ahasia na ia gabuna ai e lohia.$h$),
    -- 1KI 22:50: King Ahasia
    ('5b1840a2-f7ce-46f2-a234-3ccfd9338058'::uuid, $h$Bena Iehosafat na tubu tama dekediai e mahuta; idia dekediai e guria, senena David ena hanua ai. Bena ia natuna Iehoram ese ia gabuna ai e lohia. King Ahasia$h$,
     $h$Bena Iehosafat na tubu tama dekediai e mahuta; idia dekediai e guria, senena David ena hanua ai. Bena ia natuna Iehoram ese ia gabuna ai e lohia.$h$),
    -- 1PE 1:2: Heimodai
    ('e9d8ce83-e0de-4fd8-a7ec-4d85bb0ebb78'::uuid, $h$Ita Tamada Dirava ese e abimui hidi guna, bena Lauma Helaḡa ese e hahelaḡamui, Iesu Keriso ba kamonai henia bena ia rarana ese baine nevarimui helaoreana. Hariharibada bona maino emui ai bae bada. Heimodai$h$,
     $h$Ita Tamada Dirava ese e abimui hidi guna, bena Lauma Helaḡa ese e hahelaḡamui, Iesu Keriso ba kamonai henia bena ia rarana ese baine nevarimui helaoreana. Hariharibada bona maino emui ai bae bada.$h$),
    -- 1SA 1:8: Hana ena ḡuriḡuri
    ('84148acd-f70d-47ad-b7c5-6cdfa170f596'::uuid, $h$Bena adavana Elkana ese e nanadaia, eto, Hana e, dahaka dainai o taitaimu? Dahaka dainai so anianimu? Dahaka dainai lalomu e hisihisimu? Egu lalokau oiemu ai ese memero gwauta edia se hereaia a? Hana ena ḡuriḡuri$h$,
     $h$Bena adavana Elkana ese e nanadaia, eto, Hana e, dahaka dainai o taitaimu? Dahaka dainai so anianimu? Dahaka dainai lalomu e hisihisimu? Egu lalokau oiemu ai ese memero gwauta edia se hereaia a?$h$),
    -- 1SA 1:8: Hana ena ḡuriḡuri
    ('e7273ef5-2c76-4500-9642-6e9a3d774598'::uuid, $h$Bena adavana Elkana ese e nanadaia, eto, Hana e, dahaka dainai o taitaimu? Dahaka dainai so anianimu? Dahaka dainai lalomu e hisihisimu? Egu lalokau oiemu ai ese memero gwauta edia se hereaia a? Hana ena ḡuriḡuri$h$,
     $h$Bena adavana Elkana ese e nanadaia, eto, Hana e, dahaka dainai o taitaimu? Dahaka dainai so anianimu? Dahaka dainai lalomu e hisihisimu? Egu lalokau oiemu ai ese memero gwauta edia se hereaia a?$h$),
    -- 1SA 1:18: Samuel e vara
    ('b7bec02a-eb5d-4f89-a542-0820a47d8ced'::uuid, $h$Hahine ma eto, Emu hesiai hahinena ba hanamoa. Bena hahine na ena dala ela, e aniani, vairana danu se huaia lou. Samuel e vara$h$,
     $h$Hahine ma eto, Emu hesiai hahinena ba hanamoa. Bena hahine na ena dala ela, e aniani, vairana danu se huaia lou.$h$),
    -- 1SA 2:10: Samuel na dubu ai
    ('112508af-f1b2-4d0d-b58e-a30c3e8b72e8'::uuid, $h$Iehova inaina bae hehuari kohi; ia ese guba baine harahurahu henidia. Iehova ese tanobada dokodia baine hahemaoro henidia; e duanaia pavapavana na ia ese goada baine henia, bona e horoa tauna na ia ese ena siahu baine habadaia. Samuel na dubu ai$h$,
     $h$Iehova inaina bae hehuari kohi; ia ese guba baine harahurahu henidia. Iehova ese tanobada dokodia baine hahemaoro henidia; e duanaia pavapavana na ia ese goada baine henia, bona e horoa tauna na ia ese ena siahu baine habadaia.$h$),
    -- 1SA 2:10: Samuel na dubu ai
    ('25a9273e-fced-4ff6-b9ab-fbed05a54f21'::uuid, $h$Iehova inaina bae hehuari kohi; ia ese guba baine harahurahu henidia. Iehova ese tanobada dokodia baine hahemaoro henidia; e duanaia pavapavana na ia ese goada baine henia, bona e horoa tauna na ia ese ena siahu baine habadaia. Samuel na dubu ai$h$,
     $h$Iehova inaina bae hehuari kohi; ia ese guba baine harahurahu henidia. Iehova ese tanobada dokodia baine hahemaoro henidia; e duanaia pavapavana na ia ese goada baine henia, bona e horoa tauna na ia ese ena siahu baine habadaia.$h$),
    -- 1SA 2:10: Samuel na dubu ai
    ('fda19815-945a-439a-89fd-98239b2cc200'::uuid, $h$Iehova inaina bae hehuari kohi; ia ese guba baine harahurahu henidia. Iehova ese tanobada dokodia baine hahemaoro henidia; e duanaia pavapavana na ia ese goada baine henia, bona e horoa tauna na ia ese ena siahu baine habadaia. Samuel na dubu ai$h$,
     $h$Iehova inaina bae hehuari kohi; ia ese guba baine harahurahu henidia. Iehova ese tanobada dokodia baine hahemaoro henidia; e duanaia pavapavana na ia ese goada baine henia, bona e horoa tauna na ia ese ena siahu baine habadaia.$h$),
    -- 1SA 10:16: Hebou ese Saulo e abia dae
    ('450852ac-c188-4006-a4e6-61c03d489c48'::uuid, $h$Saulo ese tama-lahaina e haere henia, eto, E hadibamai, doniki vada e davaridia. A hari basileia herevana Samuel ese e gwauraia na herevana ta se hamaorolaia. Hebou ese Saulo e abia dae$h$,
     $h$Saulo ese tama-lahaina e haere henia, eto, E hadibamai, doniki vada e davaridia. A hari basileia herevana Samuel ese e gwauraia na herevana ta se hamaorolaia.$h$),
    -- 1SA 15:33: Samuel ese Saulo e rakatania
    ('328a8af6-f6ee-4b64-a3d2-55115da1d78b'::uuid, $h$Bena Samuel eto, Hahine na asi natudia e nohomu oiemu dare dainai, heḡereḡerena oi sinamu na asi natuna baine noho. Bena Samuel ese Agag e dapaia sisi, Iehova vairanai, Gilgal ai. Samuel ese Saulo e rakatania$h$,
     $h$Bena Samuel eto, Hahine na asi natudia e nohomu oiemu dare dainai, heḡereḡerena oi sinamu na asi natuna baine noho. Bena Samuel ese Agag e dapaia sisi, Iehova vairanai, Gilgal ai.$h$),
    -- 1SA 25:1: Abigail
    ('5add60fe-5826-4297-861f-0d4ec657c1c5'::uuid, $h$Una negana ai Samuel e mase; bena Israel taudia iboudiai e hebou, ia taina e taiva. Bena ena ruma ai e ḡuria, Rama ai. Bena David e tore isi, Paran tano-ḡaḡaena ela. Abigail$h$,
     $h$Una negana ai Samuel e mase; bena Israel taudia iboudiai e hebou, ia taina e taiva. Bena ena ruma ai e ḡuria, Rama ai. Bena David e tore isi, Paran tano-ḡaḡaena ela.$h$),
    -- 1TH 1:1: Emai moale na daimui ai
    ('2b3150c6-930b-4e71-b75e-9885a85bac00'::uuid, $h$Ai taloiosi, Paulo bona Siluano bona Timoteo, ese Tamada Dirava bona Lohiabada Iesu Keriso edia ekalesia oreana Tesalonika ai a tore henimuimu: harihari-bada bona maimo bavabi. Emai moale na daimui ai$h$,
     $h$Ai taloiosi, Paulo bona Siluano bona Timoteo, ese Tamada Dirava bona Lohiabada Iesu Keriso edia ekalesia oreana Tesalonika ai a tore henimuimu: harihari-bada bona maimo bavabi.$h$),
    -- 1TH 1:1: Emai moale na daimui ai
    ('f7370e67-f099-46e6-9542-66d69e0fa899'::uuid, $h$Ai taloiosi, Paulo bona Siluano bona Timoteo, ese Tamada Dirava bona Lohiabada Iesu Keriso edia ekalesia oreana Tesalonika ai a tore henimuimu: harihari-bada bona maimo bavabi. Emai moale na daimui ai$h$,
     $h$Ai taloiosi, Paulo bona Siluano bona Timoteo, ese Tamada Dirava bona Lohiabada Iesu Keriso edia ekalesia oreana Tesalonika ai a tore henimuimu: harihari-bada bona maimo bavabi.$h$),
    -- 1TH 2:16: Lalomai e hekwarahimu daimui ai
    ('2a3e891d-0e59-4b2b-b59d-f44f4ad76eea'::uuid, $h$ai danu e gwaumai taomu, idau bese taudia mauri herevadia basia harorolai henidia e tomamu. Edia kara dika e haḡuḡurumu; Dirava ena badu na latadiai vada e kau, baine habuadia tari. Lalomai e hekwarahimu daimui ai$h$,
     $h$ai danu e gwaumai taomu, idau bese taudia mauri herevadia basia harorolai henidia e tomamu. Edia kara dika e haḡuḡurumu; Dirava ena badu na latadiai vada e kau, baine habuadia tari.$h$),
    -- 1TH 4:12: Mase taudia
    ('034d9c26-8ea5-4e45-b32a-57d51ca46fab'::uuid, $h$Unu amo murimuri taudia vairadiai ba raka bena idia ese bae matauraimui, bona ḡau ta ai basio dabu. Mase taudia$h$,
     $h$Unu amo murimuri taudia vairadiai ba raka bena idia ese bae matauraimui, bona ḡau ta ai basio dabu.$h$),
    -- 1TI 6:16: Hahetoni herevadia
    ('e5facb02-b87d-4d13-aaff-013ec80253f6'::uuid, $h$ia sibona e noho hanaihanaimu, asi iraka-kahikahina diarina ai e nohomu; ta ese asine itaia, bona ta ese basine itaia diba. Hemataurai bona siahu ienai bae mia hanaihanai. Amen. Hahetoni herevadia$h$,
     $h$ia sibona e noho hanaihanaimu, asi iraka-kahikahina diarina ai e nohomu; ta ese asine itaia, bona ta ese basine itaia diba. Hemataurai bona siahu ienai bae mia hanaihanai. Amen.$h$),
    -- 2CH 3:14: Hurama ena ḡaukara dubu ai
    ('23a0cecb-e160-40c2-afe6-10c84a7e45a8'::uuid, $h$Ia ese seseahu na dabua vaiunna bona mia-kakana bona kakakakana bona aukana amo e karaia, bona kerubi laulaudia na seseahu dabuana ai e turi kau. Hurama ena ḡaukara dubu ai$h$,
     $h$Ia ese seseahu na dabua vaiunna bona mia-kakana bona kakakakana bona aukana amo e karaia, bona kerubi laulaudia na seseahu dabuana ai e turi kau.$h$),
    -- 2CH 29:2: Hesekia ese dubu e kehoa lou
    ('265269a3-1781-4c27-8bdf-18fc8b0d8758'::uuid, $h$Ia na Iehova vairanai e kara maoromaoroava, senena David ena kara iboudiai heḡereḡeredia ai e karava. Hesekia ese dubu e kehoa lou$h$,
     $h$Ia na Iehova vairanai e kara maoromaoroava, senena David ena kara iboudiai heḡereḡeredia ai e karava.$h$),
    -- 2CH 32:31: King Hesekia e mase
    ('806c8127-0852-4e0a-99e5-da2131e34005'::uuid, $h$Taunabunai, Babulono lohiadia ese edia gwaukau taudia na ia dekena e siaidia, una tano ai vada e hedinarai toana bae henanadailaia eto negana ai, Dirava ese e rakatania ḡaḡae, baine tohoa bona lalona idoinai baine dibaia helaoreana. King Hesekia e mase$h$,
     $h$Taunabunai, Babulono lohiadia ese edia gwaukau taudia na ia dekena e siaidia, una tano ai vada e hedinarai toana bae henanadailaia eto negana ai, Dirava ese e rakatania ḡaḡae, baine tohoa bona lalona idoinai baine dibaia helaoreana.$h$),
    -- 2CH 32:31: King Hesekia e mase
    ('ef3d9515-5d1e-4c8c-86bd-ff0ce03f81d4'::uuid, $h$Taunabunai, Babulono lohiadia ese edia gwaukau taudia na ia dekena e siaidia, una tano ai vada e hedinarai toana bae henanadailaia eto negana ai, Dirava ese e rakatania ḡaḡae, baine tohoa bona lalona idoinai baine dibaia helaoreana. King Hesekia e mase$h$,
     $h$Taunabunai, Babulono lohiadia ese edia gwaukau taudia na ia dekena e siaidia, una tano ai vada e hedinarai toana bae henanadailaia eto negana ai, Dirava ese e rakatania ḡaḡae, baine tohoa bona lalona idoinai baine dibaia helaoreana.$h$),
    -- 2CH 36:10: King Sedekia
    ('a79b6208-9311-4c94-93e6-43b27e18176f'::uuid, $h$Bena gara-kau negana ai, King Nebukadnesara e hesiai, bena Babulono e hakaua lao; Iehova ena dubu kohudia herea-daedia danu e laohai. Bena kakana Sedekia na Iuda bona Ierusalem pavapavana ai e halaoa. King Sedekia$h$,
     $h$Bena gara-kau negana ai, King Nebukadnesara e hesiai, bena Babulono e hakaua lao; Iehova ena dubu kohudia herea-daedia danu e laohai. Bena kakana Sedekia na Iuda bona Ierusalem pavapavana ai e halaoa.$h$),
    -- 2CH 36:16: Iuda iabi-maurina
    ('5c79b699-dd99-4b42-bbb6-b376107acbad'::uuid, $h$A vaia idia ese Dirava ena gwaukau taudia e ḡonaḡonalaidia, ena hereva e dadaraidia bona ena peroveta taudia e hevasehalaidia, ela bona Iehova ena badu e vara, ena bese taudia latadiai, ela bona asi ihanamo-louna dalana. Iuda iabi-maurina$h$,
     $h$A vaia idia ese Dirava ena gwaukau taudia e ḡonaḡonalaidia, ena hereva e dadaraidia bona ena peroveta taudia e hevasehalaidia, ela bona Iehova ena badu e vara, ena bese taudia latadiai, ela bona asi ihanamo-louna dalana.$h$),
    -- 2CH 36:16: Iuda iabi-maurina
    ('946365d4-9d55-4a8e-ad55-35f67220b8dc'::uuid, $h$A vaia idia ese Dirava ena gwaukau taudia e ḡonaḡonalaidia, ena hereva e dadaraidia bona ena peroveta taudia e hevasehalaidia, ela bona Iehova ena badu e vara, ena bese taudia latadiai, ela bona asi ihanamo-louna dalana. Iuda iabi-maurina$h$,
     $h$A vaia idia ese Dirava ena gwaukau taudia e ḡonaḡonalaidia, ena hereva e dadaraidia bona ena peroveta taudia e hevasehalaidia, ela bona Iehova ena badu e vara, ena bese taudia latadiai, ela bona asi ihanamo-louna dalana.$h$),
    -- 2CH 36:21: Kurese ena Haheḡani
    ('0f864de2-aeeb-41e2-a6c6-b23bd147a05b'::uuid, $h$Unuheto Iehova ena hereva Ieremia uduna amo e gwauraia na vada e hamomokania, ela bona tano ese ena dina helaḡadia vada e moalelaidia. Una e haḡaḡaea dinadia iboudiai na e helaga, ela bona laḡani hitu-ahui e ore. Kurese ena Haheḡani$h$,
     $h$Unuheto Iehova ena hereva Ieremia uduna amo e gwauraia na vada e hamomokania, ela bona tano ese ena dina helaḡadia vada e moalelaidia. Una e haḡaḡaea dinadia iboudiai na e helaga, ela bona laḡani hitu-ahui e ore.$h$),
    -- 2CH 36:21: Kurese ena Haheḡani
    ('4815bc8a-f226-49da-b073-6f497703233a'::uuid, $h$Unuheto Iehova ena hereva Ieremia uduna amo e gwauraia na vada e hamomokania, ela bona tano ese ena dina helaḡadia vada e moalelaidia. Una e haḡaḡaea dinadia iboudiai na e helaga, ela bona laḡani hitu-ahui e ore. Kurese ena Haheḡani$h$,
     $h$Unuheto Iehova ena hereva Ieremia uduna amo e gwauraia na vada e hamomokania, ela bona tano ese ena dina helaḡadia vada e moalelaidia. Una e haḡaḡaea dinadia iboudiai na e helaga, ela bona laḡani hitu-ahui e ore.$h$),
    -- 2CO 1:13: Egu vasi herevadia
    ('0786b062-cc52-44c9-9f5c-760e373e7531'::uuid, $h$Badina be ai ese hereva hehunidia asia tore henimuimu, a ba duahidia diba bona anidia ba lalo-davari herevadia mo. Egu helaro be harihari do asio dibadia ḡoevaḡoeva ḡaudia na anidia ba diba vaitani. Bena umui ese ba heaḡilaimai, ai ese baia heaḡilaimui heḡereḡerena ai, eda Lohiabada Iesu ena dina ai. Egu vasi herevadia$h$,
     $h$Badina be ai ese hereva hehunidia asia tore henimuimu, a ba duahidia diba bona anidia ba lalo-davari herevadia mo. Egu helaro be harihari do asio dibadia ḡoevaḡoeva ḡaudia na anidia ba diba vaitani. Bena umui ese ba heaḡilaimai, ai ese baia heaḡilaimui heḡereḡerena ai, eda Lohiabada Iesu ena dina ai.$h$),
    -- 2CO 1:13: Egu vasi herevadia
    ('70c77248-269d-4979-9fb5-d8e9961f96d7'::uuid, $h$Badina be ai ese hereva hehunidia asia tore henimuimu, a ba duahidia diba bona anidia ba lalo-davari herevadia mo. Egu helaro be harihari do asio dibadia ḡoevaḡoeva ḡaudia na anidia ba diba vaitani. Bena umui ese ba heaḡilaimai, ai ese baia heaḡilaimui heḡereḡerena ai, eda Lohiabada Iesu ena dina ai. Egu vasi herevadia$h$,
     $h$Badina be ai ese hereva hehunidia asia tore henimuimu, a ba duahidia diba bona anidia ba lalo-davari herevadia mo. Egu helaro be harihari do asio dibadia ḡoevaḡoeva ḡaudia na anidia ba diba vaitani. Bena umui ese ba heaḡilaimai, ai ese baia heaḡilaimui heḡereḡerena ai, eda Lohiabada Iesu ena dina ai.$h$),
    -- 2CO 2:3: Egu revareva gunana badina
    ('8d8f2f8c-33b0-4344-9023-d1514c57ccf4'::uuid, $h$Bena egu revareva ta na torea, baina vasi negana ai ihamoalegu taudia ese bae hahisigu na garina. Na abidadama henimuimu, lauegu moale ai umui danu ba moale. Egu revareva gunana badina$h$,
     $h$Bena egu revareva ta na torea, baina vasi negana ai ihamoalegu taudia ese bae hahisigu na garina. Na abidadama henimuimu, lauegu moale ai umui danu ba moale.$h$),
    -- 2CO 7:4: Tito ena heigo-ita
    ('56d10401-3999-4f50-b269-ad52204cda5a'::uuid, $h$Lau na abidadama henimuimu, na heaḡilaimuimu. Emai hisihisi iboudiai lalodiai taugu eme lo, bona na moale badamu. Tito ena heigo-ita$h$,
     $h$Lau na abidadama henimuimu, na heaḡilaimuimu. Emai hisihisi iboudiai lalodiai taugu eme lo, bona na moale badamu.$h$),
    -- 2CO 12:13: Egu heigo-ita ihatoina
    ('6521f749-034b-4356-b61c-581f28cf5a0f'::uuid, $h$Edena ḡau ekalesia oreadia idaudia ese e abia a umuiasio abia a? Ina tamona mo: asina hahekwarahimui. Mani ina egu dika tamona ba laloa nege. Egu heigo-ita ihatoina$h$,
     $h$Edena ḡau ekalesia oreadia idaudia ese e abia a umuiasio abia a? Ina tamona mo: asina hahekwarahimui. Mani ina egu dika tamona ba laloa nege.$h$),
    -- 2KI 3:3: Elisaia ese kwalimu e gwauraia guna
    ('fb9b746c-e9db-42fa-91ae-c7fc10d36cd2'::uuid, $h$Ḡau tamona, Ieroboam Nebata ena kara dika, Israel e hakaralaia dika ḡauna, na ia ese e dogoa tao, se rakatania. Elisaia ese kwalimu e gwauraia guna$h$,
     $h$Ḡau tamona, Ieroboam Nebata ena kara dika, Israel e hakaralaia dika ḡauna, na ia ese e dogoa tao, se rakatania.$h$),
    -- 2KI 8:6: Hasaele ese Suria e lohiaia matama
    ('45f5d602-e722-44f8-9113-6725f847853c'::uuid, $h$Hanua pavapavana ese hahine na e nanadaia, bena ia ese sivarai ma e gwauraia. Taunabunai, hanua pavapavana ese ena ḡaukara itataona tauna ta e haḡania, eto, Ena ḡau iboudiai ba henia lou, bona uma anidia iboudiai danu, e raka oho dinana amo ema bona hari. Hasaele ese Suria e lohiaia matama$h$,
     $h$Hanua pavapavana ese hahine na e nanadaia, bena ia ese sivarai ma e gwauraia. Taunabunai, hanua pavapavana ese ena ḡaukara itataona tauna ta e haḡania, eto, Ena ḡau iboudiai ba henia lou, bona uma anidia iboudiai danu, e raka oho dinana amo ema bona hari.$h$),
    -- 2KI 9:13: Iehu ese Ioram e alaia mase
    ('d3e73109-6d52-4f35-9f0d-a221ecec2a0b'::uuid, $h$Bena idia iboudiai ta ta ena dabua e doki oho haraḡa-haraga, ia henuna vadavadadia kavakava latadiai e laha. Bena kibi e hiriria, eto, Iehu na pavapava. Iehu ese Ioram e alaia mase$h$,
     $h$Bena idia iboudiai ta ta ena dabua e doki oho haraḡa-haraga, ia henuna vadavadadia kavakava latadiai e laha. Bena kibi e hiriria, eto, Iehu na pavapava.$h$),
    -- 2KI 15:7: Sekana, Israel pavapavana
    ('986ac73e-eaaa-48c2-839f-df150452f253'::uuid, $h$Bena Asaria na tubu tama dekediai e mahuta; senena ida e guria, David ena hanua ai. Bena natuna lotam na ia gabuna ai e lohia. Sekana, Israel pavapavana$h$,
     $h$Bena Asaria na tubu tama dekediai e mahuta; senena ida e guria, David ena hanua ai. Bena natuna lotam na ia gabuna ai e lohia.$h$),
    -- 2KI 15:12: Salumu, Israel pavapavana
    ('19bf22cf-f048-45ad-ade4-eaee0df3c1be'::uuid, $h$Ina na Iehova ena gwauhamata, ia ese Iehu e gvau henia hamata, eto, Oi garamu na Israel teronona ai bae helai ela bona uru ihahanina. Bena unu vada e vara toma. Salumu, Israel pavapavana$h$,
     $h$Ina na Iehova ena gwauhamata, ia ese Iehu e gvau henia hamata, eto, Oi garamu na Israel teronona ai bae helai ela bona uru ihahanina. Bena unu vada e vara toma.$h$),
    -- 2KI 15:22: Pekahia, Israel pavapavana
    ('2dc2bd82-3f9b-4ff9-b439-f5816d739fb6'::uuid, $h$Bena Menaheme na tubu tama dekediai e mahuta; ia natuna Pekahia na ia gabuna ai e lohia. Pekahia, Israel pavapavana$h$,
     $h$Bena Menaheme na tubu tama dekediai e mahuta; ia natuna Pekahia na ia gabuna ai e lohia.$h$),
    -- 2KI 18:12: Asuria pavapavana ese Iuda e tuari henia
    ('1636c723-8917-4dcd-8a00-d21132134d38'::uuid, $h$Badina be Iehova, edia Dirava, gadona asie kamonaiva, a ena taravatu, Iehova ena hesiai tauna Mose ese e haḡanilaidia ḡaudia iboudiai, na e tata utuva; idia na asie hakalava, bona asie kamonai heniava. Asuria pavapavana ese Iuda e tuari henia$h$,
     $h$Badina be Iehova, edia Dirava, gadona asie kamonaiva, a ena taravatu, Iehova ena hesiai tauna Mose ese e haḡanilaidia ḡaudia iboudiai, na e tata utuva; idia na asie hakalava, bona asie kamonai heniava.$h$),
    -- 2KI 18:12: Asuria pavapavana ese Iuda e tuari henia
    ('91adaa94-2d2e-4fe8-af2b-c609010c634d'::uuid, $h$Badina be Iehova, edia Dirava, gadona asie kamonaiva, a ena taravatu, Iehova ena hesiai tauna Mose ese e haḡanilaidia ḡaudia iboudiai, na e tata utuva; idia na asie hakalava, bona asie kamonai heniava. Asuria pavapavana ese Iuda e tuari henia$h$,
     $h$Badina be Iehova, edia Dirava, gadona asie kamonaiva, a ena taravatu, Iehova ena hesiai tauna Mose ese e haḡanilaidia ḡaudia iboudiai, na e tata utuva; idia na asie hakalava, bona asie kamonai heniava.$h$),
    -- 2KI 20:11: Gwau-kau taudia Babulono amo
    ('190e2867-5efb-4558-9048-387444da5c3c'::uuid, $h$Bena peroveta tauna Isaia ese Iehova e tai henia; bena Iehova ese ikerukeru na vadavada gwauta amo e haloua, dina gelona ai Ahasa ena dina-hahetohona ḡauna ai vada e ikerukeru gaudia. Gwau-kau taudia Babulono amo$h$,
     $h$Bena peroveta tauna Isaia ese Iehova e tai henia; bena Iehova ese ikerukeru na vadavada gwauta amo e haloua, dina gelona ai Ahasa ena dina-hahetohona ḡauna ai vada e ikerukeru gaudia.$h$),
    -- 2KI 20:11: Gwau-kau taudia Babulono amo
    ('5feea44b-570c-4ac0-9655-148cda9c26b9'::uuid, $h$Bena peroveta tauna Isaia ese Iehova e tai henia; bena Iehova ese ikerukeru na vadavada gwauta amo e haloua, dina gelona ai Ahasa ena dina-hahetohona ḡauna ai vada e ikerukeru gaudia. Gwau-kau taudia Babulono amo$h$,
     $h$Bena peroveta tauna Isaia ese Iehova e tai henia; bena Iehova ese ikerukeru na vadavada gwauta amo e haloua, dina gelona ai Ahasa ena dina-hahetohona ḡauna ai vada e ikerukeru gaudia.$h$),
    -- 2KI 20:19: King Hesekia e mase
    ('c077dc4d-761e-4b2b-ac3d-e62f60fb5f57'::uuid, $h$Bena Hesekia ese Isaia e hamaoroa, eto, Iehova ena hereva oi ese vada o gwauraia na hereva namona. Badina be Hesekia na ini e helalo toma, eto, Herevana, lauegu dina lalodiai maino bona noho-namo bae mia. King Hesekia e mase$h$,
     $h$Bena Hesekia ese Isaia e hamaoroa, eto, Iehova ena hereva oi ese vada o gwauraia na hereva namona. Badina be Hesekia na ini e helalo toma, eto, Herevana, lauegu dina lalodiai maino bona noho-namo bae mia.$h$),
    -- 2KI 21:18: Amon, Iuda pavapavana
    ('4d644aa5-43b3-48d6-ab8e-43199bb3c8d6'::uuid, $h$Bena Manase na tubu tama dekediai e mahuta; iena ruma uma-umana lalonai, Usa ena uma-uma ai, e guria. Bena natuna Amon na ia gabuna ai e lohia. Amon, Iuda pavapavana$h$,
     $h$Bena Manase na tubu tama dekediai e mahuta; iena ruma uma-umana lalonai, Usa ena uma-uma ai, e guria. Bena natuna Amon na ia gabuna ai e lohia.$h$),
    -- 2KI 21:18: Amon, Iuda pavapavana
    ('5a37e430-1bff-4756-85e4-29eaf12ce69d'::uuid, $h$Bena Manase na tubu tama dekediai e mahuta; iena ruma uma-umana lalonai, Usa ena uma-uma ai, e guria. Bena natuna Amon na ia gabuna ai e lohia. Amon, Iuda pavapavana$h$,
     $h$Bena Manase na tubu tama dekediai e mahuta; iena ruma uma-umana lalonai, Usa ena uma-uma ai, e guria. Bena natuna Amon na ia gabuna ai e lohia.$h$),
    -- 2KI 24:7: Iehoiakini, Iuda pavapavana
    ('2e639903-22ed-462f-9d20-9343079d4126'::uuid, $h$Una negana ai Aigupto pavapavana na ena tano amo se raka lasi lou, badina be Babulono pavapavana ese Aigupto pavapavana ena tano, Aigupto sinavaina amo ela bona Eufrate sinavaina, iboudiai vada e abidia. Iehoiakini, Iuda pavapavana$h$,
     $h$Una negana ai Aigupto pavapavana na ena tano amo se raka lasi lou, badina be Babulono pavapavana ese Aigupto pavapavana ena tano, Aigupto sinavaina amo ela bona Eufrate sinavaina, iboudiai vada e abidia.$h$),
    -- 2KI 24:17: Sedekia, Iuda pavapavana
    ('38b08a49-2071-48da-8708-71fc4c52bdfd'::uuid, $h$Bena Babulono pavapavana ese Matania, Iehoiakini tamana lahaina, na pavapavana ai e halaoa, ia gabuna ai, bona lada matamatana e henia, e nemaia Sedekia. Sedekia, Iuda pavapavana$h$,
     $h$Bena Babulono pavapavana ese Matania, Iehoiakini tamana lahaina, na pavapavana ai e halaoa, ia gabuna ai, bona lada matamatana e henia, e nemaia Sedekia.$h$),
    -- 2PE 1:2: Laumamui ihagoadadia
    ('a9b970b7-c62d-4076-8603-dfadf9ff5417'::uuid, $h$harihari-bada bona maino emui ai bae bada, emui laloparara danu Dirava enai bona eda Lohiabada Iesu Keriso enai baine bada. Laumamui ihagoadadia$h$,
     $h$harihari-bada bona maino emui ai bae bada, emui laloparara danu Dirava enai bona eda Lohiabada Iesu Keriso enai baine bada.$h$),
    -- 2PE 3:10: Ba noho migomigo
    ('45a2d1b9-67b1-4ff9-bdca-a19b016715eb'::uuid, $h$A Lohiabada ena dina baine kau, henao tauna na heto; una dina ai guba baine puki mai rege-badana ida, ḡau iboudiai na siahu badana ese baine havevedia, tanobada danu, mai anina idoinai ida, lahi ese baine araia ore. Ba noho migomigo$h$,
     $h$A Lohiabada ena dina baine kau, henao tauna na heto; una dina ai guba baine puki mai rege-badana ida, ḡau iboudiai na siahu badana ese baine havevedia, tanobada danu, mai anina idoinai ida, lahi ese baine araia ore.$h$),
    -- 2SA 1:16: David ese Saulo bona Ionatan taidia e tai
    ('4e7d020e-08a5-4577-af99-e281e87bba2e'::uuid, $h$David ese e hamaoroa, eto, Raramu be sibomu kwaramu ai, badina be sibomu vada o hahebade, oto “Iehova ese e horoa tauna na na alaia mase”. David ese Saulo bona Ionatan taidia e tai$h$,
     $h$David ese e hamaoroa, eto, Raramu be sibomu kwaramu ai, badina be sibomu vada o hahebade, oto “Iehova ese e horoa tauna na na alaia mase”.$h$),
    -- 2SA 2:17: Abnere ese Asahele e alaia mase
    ('76d11b9d-14ae-4a17-a6c7-744361139735'::uuid, $h$Una dina ai tuari na auka herea, bona David ena hesiai taudia ese Abnere bona Israel taudia na e hadareredia. Abnere ese Asahele e alaia mase$h$,
     $h$Una dina ai tuari na auka herea, bona David ena hesiai taudia ese Abnere bona Israel taudia na e hadareredia.$h$),
    -- 2SA 3:5: Abnere na David ida e herohemalno
    ('231e643c-b2c7-48aa-a83d-faa8a3890967'::uuid, $h$Ihatauratoina na Itireama, David adavana Egla natuna. Una na David ese e havaradia, Heberon ai. Abnere na David ida e herohemalno$h$,
     $h$Ihatauratoina na Itireama, David adavana Egla natuna. Una na David ese e havaradia, Heberon ai.$h$),
    -- 2SA 3:5: Abnere na David ida e herohemalno
    ('487ff5aa-6420-4016-8a3e-8bca84cb4e89'::uuid, $h$Ihatauratoina na Itireama, David adavana Egla natuna. Una na David ese e havaradia, Heberon ai. Abnere na David ida e herohemalno$h$,
     $h$Ihatauratoina na Itireama, David adavana Egla natuna. Una na David ese e havaradia, Heberon ai.$h$),
    -- 2SA 3:5: Abnere na David ida e herohemalno
    ('d607dd7f-4a26-43bd-bda0-f85de8454a44'::uuid, $h$Ihatauratoina na Itireama, David adavana Egla natuna. Una na David ese e havaradia, Heberon ai. Abnere na David ida e herohemalno$h$,
     $h$Ihatauratoina na Itireama, David adavana Egla natuna. Una na David ese e havaradia, Heberon ai.$h$),
    -- 2SA 3:21: Ioab ese Abnere e alaia mase
    ('f5c2bb21-03ef-498e-9668-c0b4acfcc1c7'::uuid, $h$Bena Abnere ese David e hamaoroa, eto, Aina tore isi, bainala, Israel taudia iboudiai baina haboudia, egu lohia bona egu pavapava vairamu ai. Idia na oi ida bae herohemaino; bena o ura henidiamu taudia iboudiai na ba biagudia. Taunabunai David ese Abnere e siaia oho; ia na mai mainona ida ela. Ioab ese Abnere e alaia mase$h$,
     $h$Bena Abnere ese David e hamaoroa, eto, Aina tore isi, bainala, Israel taudia iboudiai baina haboudia, egu lohia bona egu pavapava vairamu ai. Idia na oi ida bae herohemaino; bena o ura henidiamu taudia iboudiai na ba biagudia. Taunabunai David ese Abnere e siaia oho; ia na mai mainona ida ela.$h$),
    -- 2SA 3:30: Abnere taina e tai
    ('4735cacd-8557-4e80-801e-ccfe9f15232b'::uuid, $h$Badina bunai Ioab bona tadina Abisai ese Abnere e alaia mase, badina be ia ese Gibeon tuarina ai idia tadidia Asahele e alaia mase davana. Abnere taina e tai$h$,
     $h$Badina bunai Ioab bona tadina Abisai ese Abnere e alaia mase, badina be ia ese Gibeon tuarina ai idia tadidia Asahele e alaia mase davana.$h$),
    -- 2SA 5:5: David ese Siona e abia
    ('45fa29b2-d9e4-449a-919e-82fd8c5d707f'::uuid, $h$Laḡani hitu hua tauratoi ia ese Iuda iduhuna e lohiaia Heberon ai, ma laḡani toi-ahui toi ia ese Israel idoinai bona Iudea idoinai e lohiadia Ierusalem ai. David ese Siona e abia$h$,
     $h$Laḡani hitu hua tauratoi ia ese Iuda iduhuna e lohiaia Heberon ai, ma laḡani toi-ahui toi ia ese Israel idoinai bona Iudea idoinai e lohiadia Ierusalem ai.$h$),
    -- 2SA 5:5: David ese Siona e abia
    ('672003a3-7680-41b0-8e94-3aec5252c3ee'::uuid, $h$Laḡani hitu hua tauratoi ia ese Iuda iduhuna e lohiaia Heberon ai, ma laḡani toi-ahui toi ia ese Israel idoinai bona Iudea idoinai e lohiadia Ierusalem ai. David ese Siona e abia$h$,
     $h$Laḡani hitu hua tauratoi ia ese Iuda iduhuna e lohiaia Heberon ai, ma laḡani toi-ahui toi ia ese Israel idoinai bona Iudea idoinai e lohiadia Ierusalem ai.$h$),
    -- 2SA 5:10: Hirama bona David
    ('b3a9a608-7ec5-4a78-af36-9d6db87bf616'::uuid, $h$Bena David na e goada e laova, badina be Dirava, Iehova Sabaota, na ia ida. Hirama bona David$h$,
     $h$Bena David na e goada e laova, badina be Dirava, Iehova Sabaota, na ia ida.$h$),
    -- 2SA 5:16: David ese Filistia taudia e hadareredia
    ('08b09824-55ce-40f9-bfaf-96c7c6c75fd3'::uuid, $h$Elisama, Eliada, Elifelete. David ese Filistia taudia e hadareredia$h$,
     $h$Elisama, Eliada, Elifelete.$h$),
    -- 2SA 5:16: David ese Filistia taudia e hadareredia
    ('fd4da0ad-9828-4357-a949-c7857ba94343'::uuid, $h$Elisama, Eliada, Elifelete. David ese Filistia taudia e hadareredia$h$,
     $h$Elisama, Eliada, Elifelete.$h$),
    -- 2SA 6:11: Maua helaḡana na Ierusalem ai e daralaia dae
    ('42fd76f9-6dcc-4457-9229-38cb2cb8aa13'::uuid, $h$Bena Iehova ena maua heḡana na Obed-edom, tau Gata, ena ruma ai e miava, hua toi; bona Iehova ese Obed-edom mai ena ruma taudia iboudiai ida e hanamodia. Maua helaḡana na Ierusalem ai e daralaia dae$h$,
     $h$Bena Iehova ena maua heḡana na Obed-edom, tau Gata, ena ruma ai e miava, hua toi; bona Iehova ese Obed-edom mai ena ruma taudia iboudiai ida e hanamodia.$h$),
    -- 2SA 6:11: Maua helaḡana na Ierusalem ai e daralaia dae
    ('578735ae-af9e-4fdf-b445-96c07d4e3b33'::uuid, $h$Bena Iehova ena maua heḡana na Obed-edom, tau Gata, ena ruma ai e miava, hua toi; bona Iehova ese Obed-edom mai ena ruma taudia iboudiai ida e hanamodia. Maua helaḡana na Ierusalem ai e daralaia dae$h$,
     $h$Bena Iehova ena maua heḡana na Obed-edom, tau Gata, ena ruma ai e miava, hua toi; bona Iehova ese Obed-edom mai ena ruma taudia iboudiai ida e hanamodia.$h$),
    -- 2SA 12:25: David ese Raba e hadarerea
    ('664aeb2d-26e5-43b7-a8ea-dd5ede691745'::uuid, $h$bona gwaukau ta peroveta tauna Natan uduna amo e siaia. Taunabunai, mero ladana ma e hatoa ledidia, Iehova dainai. David ese Raba e hadarerea$h$,
     $h$bona gwaukau ta peroveta tauna Natan uduna amo e siaia. Taunabunai, mero ladana ma e hatoa ledidia, Iehova dainai.$h$),
    -- 2SA 12:25: David ese Raba e hadarerea
    ('ca32077c-8b55-43a8-87cb-99b11430485a'::uuid, $h$bona gwaukau ta peroveta tauna Natan uduna amo e siaia. Taunabunai, mero ladana ma e hatoa ledidia, Iehova dainai. David ese Raba e hadarerea$h$,
     $h$bona gwaukau ta peroveta tauna Natan uduna amo e siaia. Taunabunai, mero ladana ma e hatoa ledidia, Iehova dainai.$h$),
    -- 2SA 15:12: David na e heau
    ('288b8015-6a2e-4e7f-a8d9-5f3a94b828c3'::uuid, $h$Absalom ese hahelaḡa karadia e karava lalonai ia ese hereva e siaia, David iduruna tauna ta ladana Ahitofel, tau Gilo, enai, ena hanua Gilo amo bainema eto. Lalo-hadai dikana e henegalaia bada; bona Absalom enai e taova taudia na e hutuma e laova. David na e heau$h$,
     $h$Absalom ese hahelaḡa karadia e karava lalonai ia ese hereva e siaia, David iduruna tauna ta ladana Ahitofel, tau Gilo, enai, ena hanua Gilo amo bainema eto. Lalo-hadai dikana e henegalaia bada; bona Absalom enai e taova taudia na e hutuma e laova.$h$),
    -- 2SA 16:14: Absalom na Ierusalem ai
    ('f8ad225b-34cb-4d3b-835f-72d63e429434'::uuid, $h$Bena hanua pavapavana mai bamona iboudiai ida na Ioridane sinavaina ai e kau, taudia na boboera. Unuseni ai laḡana e ania. Absalom na Ierusalem ai$h$,
     $h$Bena hanua pavapavana mai bamona iboudiai ida na Ioridane sinavaina ai e kau, taudia na boboera. Unuseni ai laḡana e ania.$h$),
    -- 2SA 18:8: Absalom e mase
    ('89c1fd89-f585-4539-af39-946cf42c53da'::uuid, $h$Tuari na una tano idoinai e da'ania guḡuru; hutuma na uda ahu ese e hamasedia, gadoina mo dare ai e mase. Absalom e mase$h$,
     $h$Tuari na una tano idoinai e da'ania guḡuru; hutuma na uda ahu ese e hamasedia, gadoina mo dare ai e mase.$h$),
    -- 2SA 18:8: Absalom e mase
    ('e799f4ba-59cd-46a5-ab3f-0c559f011c27'::uuid, $h$Tuari na una tano idoinai e da'ania guḡuru; hutuma na uda ahu ese e hamasedia, gadoina mo dare ai e mase. Absalom e mase$h$,
     $h$Tuari na una tano idoinai e da'ania guḡuru; hutuma na uda ahu ese e hamasedia, gadoina mo dare ai e mase.$h$),
    -- 2SA 18:8: Absalom e mase
    ('ea5a331f-f2e1-445f-b366-fc5f10318831'::uuid, $h$Tuari na una tano idoinai e da'ania guḡuru; hutuma na uda ahu ese e hamasedia, gadoina mo dare ai e mase. Absalom e mase$h$,
     $h$Tuari na una tano idoinai e da'ania guḡuru; hutuma na uda ahu ese e hamasedia, gadoina mo dare ai e mase.$h$),
    -- 2SA 19:10: King David na Ierusalem e lou lao
    ('250c7d73-2572-488a-a3fd-24e3a37cc55f'::uuid, $h$To Absalom, eda pavapava ai ta horoa tauna, na tuan ai vada e mase. Matona, hanua pavapavana ihakau-louna asio herevalaiamu badina be dahaka? King David na Ierusalem e lou lao$h$,
     $h$To Absalom, eda pavapava ai ta horoa tauna, na tuan ai vada e mase. Matona, hanua pavapavana ihakau-louna asio herevalaiamu badina be dahaka?$h$),
    -- 2SA 19:10: King David na Ierusalem e lou lao
    ('ae2bfe2d-fe8c-433f-b491-1def83322e4c'::uuid, $h$To Absalom, eda pavapava ai ta horoa tauna, na tuan ai vada e mase. Matona, hanua pavapavana ihakau-louna asio herevalaiamu badina be dahaka? King David na Ierusalem e lou lao$h$,
     $h$To Absalom, eda pavapava ai ta horoa tauna, na tuan ai vada e mase. Matona, hanua pavapavana ihakau-louna asio herevalaiamu badina be dahaka?$h$),
    -- 2TI 1:5: Emu ḡaukara
    ('e01d8cec-ccf8-4e7e-b44b-63256bb7dc9e'::uuid, $h$Emu kamonai korikori danu na helalo unelaiamu; una kamonai na gunaguna tubumu hahinena Loi bona sinamu Eunike lalodia ai e miava; lau na tomamu harihari oi lalomu ai e miamu danu. Emu ḡaukara$h$,
     $h$Emu kamonai korikori danu na helalo unelaiamu; una kamonai na gunaguna tubumu hahinena Loi bona sinamu Eunike lalodia ai e miava; lau na tomamu harihari oi lalomu ai e miamu danu.$h$),
    -- ACT 1:2: Iesu na dina hari-ahui lalodiai e hedinaraiva
    ('46eeafba-b2be-44a7-9d4c-eee483b4b9b1'::uuid, $h$ema bona e heabi isi dinana ai e abidia hidi hahedibadia e haḡanidia. Iesu na dina hari-ahui lalodiai e hedinaraiva$h$,
     $h$ema bona e heabi isi dinana ai e abidia hidi hahedibadia e haḡanidia.$h$),
    -- ACT 2:13: Petro ena haroro
    ('7d1a05d9-bfae-4db2-866c-3c67d9564e8b'::uuid, $h$A haida ese e kirikuilaidia, eto, Idia na vine ranuna matamatana e inua, e kekeromu. Petro ena haroro$h$,
     $h$A haida ese e kirikuilaidia, eto, Idia na vine ranuna matamatana e inua, e kekeromu.$h$),
    -- ACT 4:22: Ekalesia e ḡurḡuri
    ('54578e29-5393-4c30-af89-ea6f36de4386'::uuid, $h$Badina be una hoa karana ese e hamauria tauna ena vara laḡanidia na hari-ahui mai dikoana. Ekalesia e ḡurḡuri$h$,
     $h$Badina be una hoa karana ese e hamauria tauna ena vara laḡanidia na hari-ahui mai dikoana.$h$),
    -- ACT 5:11: Toa diaḡau
    ('14eb2ca6-2461-41c2-9d03-59a0283d2ec4'::uuid, $h$Una negana ai ekelesia idoinai bona harina e kamonai taudia iboudiai na gari bada ese e butudia tao. Toa diaḡau$h$,
     $h$Una negana ai ekelesia idoinai bona harina e kamonai taudia iboudiai na gari bada ese e butudia tao.$h$),
    -- ACT 6:7: Stefano e dabaia tao
    ('4246682b-b11c-4d3e-ab2a-8a7d15518eba'::uuid, $h$Bena Dirava ena hereva e piua rohorohova, bona Iesu ibadinana taudia Ierusalem ai e hahutumadiava; bona hahelaḡa taudia hutuma ese danu e abiabiraia. Stefano e dabaia tao$h$,
     $h$Bena Dirava ena hereva e piua rohorohova, bona Iesu ibadinana taudia Ierusalem ai e hahutumadiava; bona hahelaḡa taudia hutuma ese danu e abiabiraia.$h$),
    -- ACT 9:25: Saulo Ierusalem ai
    ('fb055b1f-1e3a-42d1-b6a4-a2b135985643'::uuid, $h$To Iesu ibadinana taudia ese hanuaboi ai e abia, bosea ai e udaia, maḡu gaba-matuna amo e tua dobi. Saulo Ierusalem ai$h$,
     $h$To Iesu ibadinana taudia ese hanuaboi ai e abia, bosea ai e udaia, maḡu gaba-matuna amo e tua dobi.$h$),
    -- ACT 13:5: Banaba bona Saulo Kupro ai
    ('0372a447-1512-4649-92df-c8b2e4b513d6'::uuid, $h$Salami ai eha heau kau, unuseni ai Dirava ena hereva Iuda taudia edia dubu lalodiai vada e harorolaia matama. Ioane danu idia raruosi e durudia. Banaba bona Saulo Kupro ai$h$,
     $h$Salami ai eha heau kau, unuseni ai Dirava ena hereva Iuda taudia edia dubu lalodiai vada e harorolaia matama. Ioane danu idia raruosi e durudia.$h$),
    -- ACT 15:34: PauIo ese ena laolao iharuana e matamaia
    ('7651dd5b-3b02-4fa7-a28d-286542968333'::uuid, $h$A Sila na ena ura dainai dounu e halaheva. PauIo ese ena laolao iharuana e matamaia$h$,
     $h$A Sila na ena ura dainai dounu e halaheva.$h$),
    -- ACT 16:5: Paulo Troa ai e lasi
    ('395ed9ce-3ebd-4cf3-8030-122bc200b5e7'::uuid, $h$Taunabunai, ekalesia oreadia iboudiai edia abidadama e goada e laova, bona dina iboudiai ekalesia taudia na e hutuma e laova. Paulo Troa ai e lasi$h$,
     $h$Taunabunai, ekalesia oreadia iboudiai edia abidadama e goada e laova, bona dina iboudiai ekalesia taudia na e hutuma e laova.$h$),
    -- ACT 16:9: Paulo mai bamona ida e heau hanai Makedonia ela
    ('382d5b86-d4d6-42ee-9165-be40963529da'::uuid, $h$Hanuaboina ai Paulo vada e nihi. Ena nihi ai Makedonia tauna ta e itaia, ia vairanai e gini, e noia, eto, Makedonia aoma, ame kahamai. Paulo mai bamona ida e heau hanai Makedonia ela$h$,
     $h$Hanuaboina ai Paulo vada e nihi. Ena nihi ai Makedonia tauna ta e itaia, ia vairanai e gini, e noia, eto, Makedonia aoma, ame kahamai.$h$),
    -- ACT 17:9: Berea ai
    ('b7d1b406-c813-40cc-8039-b0825588c6ba'::uuid, $h$Idia ese Iason mai bamona ida tarava e atu henidia, bena e ruhadia nege. Berea ai$h$,
     $h$Idia ese Iason mai bamona ida tarava e atu henidia, bena e ruhadia nege.$h$),
    -- ACT 17:15: Atena ai
    ('c80f27b7-ee6e-4dd2-b84d-4a26bc695d96'::uuid, $h$A Paulo inarina taudia ese e hakaua lao, Atena ai e rakatania, bona ena hahedua e loulaia, Sila bona Timoteo edia, raruosi na ia dekena baela haraḡa eto. Atena ai$h$,
     $h$A Paulo inarina taudia ese e hakaua lao, Atena ai e rakatania, bona ena hahedua e loulaia, Sila bona Timoteo edia, raruosi na ia dekena baela haraḡa eto.$h$),
    -- ACT 18:11: Paulo na Korinto ai e hahemaoro
    ('0e8fcc44-edda-47d4-95c9-659e6dd300fa'::uuid, $h$Taunabunai Paulo na laḡani ta hua tauratoi unuseni ai e noho, Dirava ena hereva e hadibalaidiava. Paulo na Korinto ai e hahemaoro$h$,
     $h$Taunabunai Paulo na laḡani ta hua tauratoi unuseni ai e noho, Dirava ena hereva e hadibalaidiava.$h$),
    -- ACT 18:17: Paulo ena laolao iharuana e ha-orea, e lou lao Antioka
    ('31c9e1d9-ee2c-44bb-87f6-8ee3586790bb'::uuid, $h$Bena idia iboudiai ese dubu biaguna, Sostene, e dabaia tao, hahemaoro gabuna vairanai e dadabaia. A Galio na una kara se haerolaia. Paulo ena laolao iharuana e ha-orea, e lou lao Antioka$h$,
     $h$Bena idia iboudiai ese dubu biaguna, Sostene, e dabaia tao, hahemaoro gabuna vairanai e dadabaia. A Galio na una kara se haerolaia.$h$),
    -- ACT 25:12: Agripa e gini dae
    ('a0ffaf3d-0e2b-42d3-b421-0de4f27ad6b2'::uuid, $h$Unu amo Festo kaunsil taudia ida vada e hereva-hereva; bena ia ese Paulo e haere henia, eto, Kaisara ladana ome hatoa; Kaisara dekena do baola. Agripa e gini dae$h$,
     $h$Unu amo Festo kaunsil taudia ida vada e hereva-hereva; bena ia ese Paulo e haere henia, eto, Kaisara ladana ome hatoa; Kaisara dekena do baola.$h$),
    -- ACT 27:12: Guba dikana
    ('022346cc-392d-4440-8c4a-dc5938553edb'::uuid, $h$Una hetu gabuna na dia namo lahara negana ai; taunabunai hutuma na e tomava baia dobitania, Foenikia ai baia heau kau toho, unuseni ai baia noho lahara negana ai. Una Foenikia na Krete aona ta, mai matuna, ta be lasirai matuna, a ta be laurabada matuna. Guba dikana$h$,
     $h$Una hetu gabuna na dia namo lahara negana ai; taunabunai hutuma na e tomava baia dobitania, Foenikia ai baia heau kau toho, unuseni ai baia noho lahara negana ai. Una Foenikia na Krete aona ta, mai matuna, ta be lasirai matuna, a ta be laurabada matuna.$h$),
    -- ACT 27:12: Guba dikana
    ('da3fe36c-3c53-46c9-bd74-7c224aace908'::uuid, $h$Una hetu gabuna na dia namo lahara negana ai; taunabunai hutuma na e tomava baia dobitania, Foenikia ai baia heau kau toho, unuseni ai baia noho lahara negana ai. Una Foenikia na Krete aona ta, mai matuna, ta be lasirai matuna, a ta be laurabada matuna. Guba dikana$h$,
     $h$Una hetu gabuna na dia namo lahara negana ai; taunabunai hutuma na e tomava baia dobitania, Foenikia ai baia heau kau toho, unuseni ai baia noho lahara negana ai. Una Foenikia na Krete aona ta, mai matuna, ta be lasirai matuna, a ta be laurabada matuna.$h$),
    -- ACT 27:12: Guba dikana
    ('f7b3fa50-da0d-4f31-a278-6eb56340e6ae'::uuid, $h$Una hetu gabuna na dia namo lahara negana ai; taunabunai hutuma na e tomava baia dobitania, Foenikia ai baia heau kau toho, unuseni ai baia noho lahara negana ai. Una Foenikia na Krete aona ta, mai matuna, ta be lasirai matuna, a ta be laurabada matuna. Guba dikana$h$,
     $h$Una hetu gabuna na dia namo lahara negana ai; taunabunai hutuma na e tomava baia dobitania, Foenikia ai baia heau kau toho, unuseni ai baia noho lahara negana ai. Una Foenikia na Krete aona ta, mai matuna, ta be lasirai matuna, a ta be laurabada matuna.$h$),
    -- ACT 28:15: Paulo Roma ai
    ('4261ffd5-e636-4187-8a94-f11ab6d63472'::uuid, $h$Varavara unuseni ai ese harimai e kamonai, bena vada ema, hanua maraḡidia ai, ladadia Apio Foro bona Taverono Toi, ai ida a hedavari. Paulo ese e itadia, bena Dirava e hanamoa; bona lalona vada e goada. Paulo Roma ai$h$,
     $h$Varavara unuseni ai ese harimai e kamonai, bena vada ema, hanua maraḡidia ai, ladadia Apio Foro bona Taverono Toi, ai ida a hedavari. Paulo ese e itadia, bena Dirava e hanamoa; bona lalona vada e goada.$h$),
    -- ACT 28:15: Paulo Roma ai
    ('4b11746b-8322-43f1-9ad8-762f02e7bc68'::uuid, $h$Varavara unuseni ai ese harimai e kamonai, bena vada ema, hanua maraḡidia ai, ladadia Apio Foro bona Taverono Toi, ai ida a hedavari. Paulo ese e itadia, bena Dirava e hanamoa; bona lalona vada e goada. Paulo Roma ai$h$,
     $h$Varavara unuseni ai ese harimai e kamonai, bena vada ema, hanua maraḡidia ai, ladadia Apio Foro bona Taverono Toi, ai ida a hedavari. Paulo ese e itadia, bena Dirava e hanamoa; bona lalona vada e goada.$h$),
    -- ACT 28:15: Paulo Roma ai
    ('5cb8717c-bc74-46f2-8613-0fd946d53c05'::uuid, $h$Varavara unuseni ai ese harimai e kamonai, bena vada ema, hanua maraḡidia ai, ladadia Apio Foro bona Taverono Toi, ai ida a hedavari. Paulo ese e itadia, bena Dirava e hanamoa; bona lalona vada e goada. Paulo Roma ai$h$,
     $h$Varavara unuseni ai ese harimai e kamonai, bena vada ema, hanua maraḡidia ai, ladadia Apio Foro bona Taverono Toi, ai ida a hedavari. Paulo ese e itadia, bena Dirava e hanamoa; bona lalona vada e goada.$h$),
    -- AMO 4:3: Israel na se helalomu
    ('727e5499-d701-4466-9090-5fb555941a6c'::uuid, $h$bena maḡu maurudia amo do ba rau lasi, ta ta vairana vairana amo baola; bae negemui daure Haramono ai. Iehova na e herevamu. Israel na se helalomu$h$,
     $h$bena maḡu maurudia amo do ba rau lasi, ta ta vairana vairana amo baola; bae negemui daure Haramono ai. Iehova na e herevamu.$h$),
    -- AMO 4:3: Israel na se helalomu
    ('8892e837-d754-441f-a0be-c798bec15a44'::uuid, $h$bena maḡu maurudia amo do ba rau lasi, ta ta vairana vairana amo baola; bae negemui daure Haramono ai. Iehova na e herevamu. Israel na se helalomu$h$,
     $h$bena maḡu maurudia amo do ba rau lasi, ta ta vairana vairana amo baola; bae negemui daure Haramono ai. Iehova na e herevamu.$h$),
    -- COL 1:2: Hahenamo herevadia
    ('232b7140-03eb-4805-9ab3-4d9bb61085d3'::uuid, $h$ai raruosi ese umui helaḡa taumui Kolose ai, Keriso iabidadama-henina taumui, a tore henimuimu: harihari-bada bona maino Tamada Dirava ena amo bavabi. Hahenamo herevadia$h$,
     $h$ai raruosi ese umui helaḡa taumui Kolose ai, Keriso iabidadama-henina taumui, a tore henimuimu: harihari-bada bona maino Tamada Dirava ena amo bavabi.$h$),
    -- COL 1:23: Lauegu ḡaukara daimui ai
    ('229ba7de-8e42-4fe3-92ee-258d9a3ba767'::uuid, $h$Ḡau tamona, kamonai ai ba noho, ba badinaia tarika-tarika, ba gini tutukatutuka; sivarai namo ena helaro amo basie daromui daudau. Sivarai namo bunai vada o kamonai; sivarai namo bunai taunimanima iboudiai guba henunai vada e harorolai henidia; sivarai namo bunai lau Paulo na hesiai tauna ai vada eme halaogu. Lauegu ḡaukara daimui ai$h$,
     $h$Ḡau tamona, kamonai ai ba noho, ba badinaia tarika-tarika, ba gini tutukatutuka; sivarai namo ena helaro amo basie daromui daudau. Sivarai namo bunai vada o kamonai; sivarai namo bunai taunimanima iboudiai guba henunai vada e harorolai henidia; sivarai namo bunai lau Paulo na hesiai tauna ai vada eme halaogu.$h$),
    -- COL 1:23: Lauegu ḡaukara daimui ai
    ('42ac71e8-92e3-40c3-bbea-8ea0e272eb93'::uuid, $h$Ḡau tamona, kamonai ai ba noho, ba badinaia tarika-tarika, ba gini tutukatutuka; sivarai namo ena helaro amo basie daromui daudau. Sivarai namo bunai vada o kamonai; sivarai namo bunai taunimanima iboudiai guba henunai vada e harorolai henidia; sivarai namo bunai lau Paulo na hesiai tauna ai vada eme halaogu. Lauegu ḡaukara daimui ai$h$,
     $h$Ḡau tamona, kamonai ai ba noho, ba badinaia tarika-tarika, ba gini tutukatutuka; sivarai namo ena helaro amo basie daromui daudau. Sivarai namo bunai vada o kamonai; sivarai namo bunai taunimanima iboudiai guba henunai vada e harorolai henidia; sivarai namo bunai lau Paulo na hesiai tauna ai vada eme halaogu.$h$),
    -- COL 4:6: Hahetoni herevadia
    ('96a7df9c-6b38-4985-b94e-6c99d6040ae7'::uuid, $h$Nega idoinai ba hereva mai gadonamomui ida; emui hereva na damena ai ba damenaia. Bena taunimanima ta ta ba haere henidia mai dibamui ida. Hahetoni herevadia$h$,
     $h$Nega idoinai ba hereva mai gadonamomui ida; emui hereva na damena ai ba damenaia. Bena taunimanima ta ta ba haere henidia mai dibamui ida.$h$),
    -- COL 4:6: Hahetoni herevadia
    ('bee3a171-ad52-4066-83b3-b51d724c70e2'::uuid, $h$Nega idoinai ba hereva mai gadonamomui ida; emui hereva na damena ai ba damenaia. Bena taunimanima ta ta ba haere henidia mai dibamui ida. Hahetoni herevadia$h$,
     $h$Nega idoinai ba hereva mai gadonamomui ida; emui hereva na damena ai ba damenaia. Bena taunimanima ta ta ba haere henidia mai dibamui ida.$h$),
    -- DAN 4:33: Nebukadnesara ena hereva
    ('1588ba6b-de85-4797-a9c8-e939925e329a'::uuid, $h$Bena asi vanahana una hereva anina e vara Nebukadnesara latanai. Taunimanima bogaragidia amo e lulua lasi, bena rei e aniva, boromakau na heto, bona tau-anina na guba hununa ese e haparipariava, ela bona huina e lata, ugava huina na heto, bona kahauna na manu kahaudia na heheto. Nebukadnesara ena hereva$h$,
     $h$Bena asi vanahana una hereva anina e vara Nebukadnesara latanai. Taunimanima bogaragidia amo e lulua lasi, bena rei e aniva, boromakau na heto, bona tau-anina na guba hununa ese e haparipariava, ela bona huina e lata, ugava huina na heto, bona kahauna na manu kahaudia na heheto.$h$),
    -- DEU 1:4: Mose ena haroro gini-gunana
    ('76808cda-168c-4307-8b00-4fe90d8d79fe'::uuid, $h$Una be Sihon, Amoro pavapavana, Hesebon ai e nohova tauna, bona Og, Basan pavapavana, Astaroto ai bona Edrei ai e nohova tauna, e hadareredia murinai. Mose ena haroro gini-gunana$h$,
     $h$Una be Sihon, Amoro pavapavana, Hesebon ai e nohova tauna, bona Og, Basan pavapavana, Astaroto ai bona Edrei ai e nohova tauna, e hadareredia murinai.$h$),
    -- DEU 4:40: Roho-mauri Hanuadia
    ('f56c4b38-da04-4b10-9608-959bc1206e3f'::uuid, $h$Taunabunai, ena taravatu bona ena haheḡani, hari dina ai na henimuimu ḡaudia, na ba badinadia; bena ba namo, bona natumui danu bae namo umui murimui ai, bona emui dina bae hoho, Iehova, emui Dirava, ese e henimui hanaihanaimu tanona ai. Roho-mauri Hanuadia$h$,
     $h$Taunabunai, ena taravatu bona ena haheḡani, hari dina ai na henimuimu ḡaudia, na ba badinadia; bena ba namo, bona natumui danu bae namo umui murimui ai, bona emui dina bae hoho, Iehova, emui Dirava, ese e henimui hanaihanaimu tanona ai.$h$),
    -- DEU 4:43: Haroro ihadokona
    ('2f42e621-aa40-45e7-812c-1d55e62c7059'::uuid, $h$Hanuadia bini: Besere, tano ḡaḡaena ororodia ai, na Ruben iduhuna taudia edia; Ramoto, Gilead ai, na Gad iduhuna taudia edia; bona Golan, Basan ai, na Manase taudia edia. Haroro ihadokona$h$,
     $h$Hanuadia bini: Besere, tano ḡaḡaena ororodia ai, na Ruben iduhuna taudia edia; Ramoto, Gilead ai, na Gad iduhuna taudia edia; bona Golan, Basan ai, na Manase taudia edia.$h$),
    -- DEU 4:43: Haroro ihadokona
    ('8236f54a-43a7-4bbc-91c0-bfe870edf588'::uuid, $h$Hanuadia bini: Besere, tano ḡaḡaena ororodia ai, na Ruben iduhuna taudia edia; Ramoto, Gilead ai, na Gad iduhuna taudia edia; bona Golan, Basan ai, na Manase taudia edia. Haroro ihadokona$h$,
     $h$Hanuadia bini: Besere, tano ḡaḡaena ororodia ai, na Ruben iduhuna taudia edia; Ramoto, Gilead ai, na Gad iduhuna taudia edia; bona Golan, Basan ai, na Manase taudia edia.$h$),
    -- DEU 4:43: Haroro ihadokona
    ('f140ecab-6bf4-40db-97bb-32a8b2d9cdfd'::uuid, $h$Hanuadia bini: Besere, tano ḡaḡaena ororodia ai, na Ruben iduhuna taudia edia; Ramoto, Gilead ai, na Gad iduhuna taudia edia; bona Golan, Basan ai, na Manase taudia edia. Haroro ihadokona$h$,
     $h$Hanuadia bini: Besere, tano ḡaḡaena ororodia ai, na Ruben iduhuna taudia edia; Ramoto, Gilead ai, na Gad iduhuna taudia edia; bona Golan, Basan ai, na Manase taudia edia.$h$),
    -- DEU 4:43: Haroro ihadokona
    ('fe1c508a-bbbd-4ea1-992c-28fc9f35c902'::uuid, $h$Hanuadia bini: Besere, tano ḡaḡaena ororodia ai, na Ruben iduhuna taudia edia; Ramoto, Gilead ai, na Gad iduhuna taudia edia; bona Golan, Basan ai, na Manase taudia edia. Haroro ihadokona$h$,
     $h$Hanuadia bini: Besere, tano ḡaḡaena ororodia ai, na Ruben iduhuna taudia edia; Ramoto, Gilead ai, na Gad iduhuna taudia edia; bona Golan, Basan ai, na Manase taudia edia.$h$),
    -- EPH 3:13: Egu ḡuriḡuri daimui ai
    ('ac6845af-b4d3-4a9b-9e65-de332d378975'::uuid, $h$Taunabunai na noimuimu, daramui basie doko umui bagumui ai na hisihisimu; lauegu hisihisi na umui ihahairaimui ḡauna. Egu ḡuriḡuri daimui ai$h$,
     $h$Taunabunai na noimuimu, daramui basie doko umui bagumui ai na hisihisimu; lauegu hisihisi na umui ihahairaimui ḡauna.$h$),
    -- EPH 4:16: Mauri matamatana ena kara
    ('79859cf8-2e3d-4e31-a771-7822085a7ab3'::uuid, $h$Ia enai garugaru iboudiai e ḡaukara heboumu, bena tau-anina idoinai vada e hesiriu kaumu bona e hekamo boumu, bona rege ta ta ena ḡaukara ena ḡaukara e karamu; unu amo tau-anina e bada oho bada ohomu, bona lalokau ai e tubumu. Mauri matamatana ena kara$h$,
     $h$Ia enai garugaru iboudiai e ḡaukara heboumu, bena tau-anina idoinai vada e hesiriu kaumu bona e hekamo boumu, bona rege ta ta ena ḡaukara ena ḡaukara e karamu; unu amo tau-anina e bada oho bada ohomu, bona lalokau ai e tubumu.$h$),
    -- EST 2:18: Morodekai ese hanua pavapavana iala-masena e laoa ahu
    ('7b3d9403-1e84-48fe-b61a-83869ff3272c'::uuid, $h$Bena hanua pavapavana ese aria badana e karaia, ena lohia bona ena hesiai taudia iboudiai adia; una na Eseta ena aria. Bona basileia iboudiai edia laḡa-ani e henidia, bona harihari ḡaudia e heni hagauhagau, pavapava ena harihari-bada heḡereḡerena. Morodekai ese hanua pavapavana iala-masena e laoa ahu$h$,
     $h$Bena hanua pavapavana ese aria badana e karaia, ena lohia bona ena hesiai taudia iboudiai adia; una na Eseta ena aria. Bona basileia iboudiai edia laḡa-ani e henidia, bona harihari ḡaudia e heni hagauhagau, pavapava ena harihari-bada heḡereḡerena.$h$),
    -- EST 9:15: Purimi Ariana
    ('84724126-4c1e-4ffe-9a8e-ee5ce983dd54'::uuid, $h$Bena Iuda taudia Susa ai na hua ladana Adara dinana ihagwauta-hanina ai ma e hebou, Susa ai tatau sinahu-toi ma e aladia mase; a kohu asie dadi. Purimi Ariana$h$,
     $h$Bena Iuda taudia Susa ai na hua ladana Adara dinana ihagwauta-hanina ai ma e hebou, Susa ai tatau sinahu-toi ma e aladia mase; a kohu asie dadi.$h$),
    -- EXO 1:7: Farao matamatana
    ('0d5d6c8e-0b57-4d22-a65f-1b7a36bc2160'::uuid, $h$A Israel garana ese natudia momo e havaradia, besedia eha hutuma, una tano e hahonua. Farao matamatana$h$,
     $h$A Israel garana ese natudia momo e havaradia, besedia eha hutuma, una tano e hahonua.$h$),
    -- EXO 2:10: Mose e kerere
    ('65cba208-1a58-4686-9812-f561992e2ef9'::uuid, $h$Mero na e bada oho bada oho, bena hari hahine ese e hakaua lao Farao natuna hahinena dekenai. Bena ia ese natuna ai e halaoa. Ia ese ladana e hatoa Mose; eto, Badina be ranu amo na veria lasi. Mose e kerere$h$,
     $h$Mero na e bada oho bada oho, bena hari hahine ese e hakaua lao Farao natuna hahinena dekenai. Bena ia ese natuna ai e halaoa. Ia ese ladana e hatoa Mose; eto, Badina be ranu amo na veria lasi.$h$),
    -- EXO 2:22: Farao e mase
    ('b40bb19c-dbfb-4081-a52d-9964f748ad60'::uuid, $h$Hahine na e mara, mero ta e abia; bena Mose ese mero ladana e hatoa Geresom; badina be ia eto, Lau na idau tano ai vada name noho hedoa. Farao e mase$h$,
     $h$Hahine na e mara, mero ta e abia; bena Mose ese mero ladana e hatoa Geresom; badina be ia eto, Lau na idau tano ai vada name noho hedoa.$h$),
    -- EXO 2:22: Farao e mase
    ('c000fb0f-3585-4963-81fe-06e011ec7cdf'::uuid, $h$Hahine na e mara, mero ta e abia; bena Mose ese mero ladana e hatoa Geresom; badina be ia eto, Lau na idau tano ai vada name noho hedoa. Farao e mase$h$,
     $h$Hahine na e mara, mero ta e abia; bena Mose ese mero ladana e hatoa Geresom; badina be ia eto, Lau na idau tano ai vada name noho hedoa.$h$),
    -- EXO 6:13: Israel ikwaradia taudia
    ('88eafb50-0c79-4cc4-b78c-b13bf0b54d05'::uuid, $h$A Iehova ese Mose bona Aaron na haheḡani e henidia, Tsrael taudia bae haḡanilaidia bona Farao, Aigupto pavapavana, bvae haḡanilaia, Israel taudia na Aigupto tanona amo bae raka lasi. Israel ikwaradia taudia$h$,
     $h$A Iehova ese Mose bona Aaron na haheḡani e henidia, Tsrael taudia bae haḡanilaidia bona Farao, Aigupto pavapavana, bvae haḡanilaia, Israel taudia na Aigupto tanona amo bae raka lasi.$h$),
    -- EXO 6:13: Israel ikwaradia taudia
    ('9e50260e-9291-46c6-9462-6825c75d1679'::uuid, $h$A Iehova ese Mose bona Aaron na haheḡani e henidia, Tsrael taudia bae haḡanilaidia bona Farao, Aigupto pavapavana, bvae haḡanilaia, Israel taudia na Aigupto tanona amo bae raka lasi. Israel ikwaradia taudia$h$,
     $h$A Iehova ese Mose bona Aaron na haheḡani e henidia, Tsrael taudia bae haḡanilaidia bona Farao, Aigupto pavapavana, bvae haḡanilaia, Israel taudia na Aigupto tanona amo bae raka lasi.$h$),
    -- EXO 6:13: Israel ikwaradia taudia
    ('a35cba67-47fc-4133-a586-eb0d5f9a7ecf'::uuid, $h$A Iehova ese Mose bona Aaron na haheḡani e henidia, Tsrael taudia bae haḡanilaidia bona Farao, Aigupto pavapavana, bvae haḡanilaia, Israel taudia na Aigupto tanona amo bae raka lasi. Israel ikwaradia taudia$h$,
     $h$A Iehova ese Mose bona Aaron na haheḡani e henidia, Tsrael taudia bae haḡanilaidia bona Farao, Aigupto pavapavana, bvae haḡanilaia, Israel taudia na Aigupto tanona amo bae raka lasi.$h$),
    -- EXO 6:13: Israel ikwaradia taudia
    ('b1a56d5d-cd33-4074-b96d-950b51044d85'::uuid, $h$A Iehova ese Mose bona Aaron na haheḡani e henidia, Tsrael taudia bae haḡanilaidia bona Farao, Aigupto pavapavana, bvae haḡanilaia, Israel taudia na Aigupto tanona amo bae raka lasi. Israel ikwaradia taudia$h$,
     $h$A Iehova ese Mose bona Aaron na haheḡani e henidia, Tsrael taudia bae haḡanilaidia bona Farao, Aigupto pavapavana, bvae haḡanilaia, Israel taudia na Aigupto tanona amo bae raka lasi.$h$),
    -- EXO 6:13: Israel ikwaradia taudia
    ('c0efe139-e9c0-4860-ae9f-b932d067b70f'::uuid, $h$A Iehova ese Mose bona Aaron na haheḡani e henidia, Tsrael taudia bae haḡanilaidia bona Farao, Aigupto pavapavana, bvae haḡanilaia, Israel taudia na Aigupto tanona amo bae raka lasi. Israel ikwaradia taudia$h$,
     $h$A Iehova ese Mose bona Aaron na haheḡani e henidia, Tsrael taudia bae haḡanilaidia bona Farao, Aigupto pavapavana, bvae haḡanilaia, Israel taudia na Aigupto tanona amo bae raka lasi.$h$),
    -- EXO 7:13: Hahehisi gini-gunana: Rara
    ('c9d0511f-88c3-443b-9ae9-15bf83b0d3bc'::uuid, $h$A Farao lalona na dounu auka, ia ese se kamonai henidia, Iehova ena hereva heḡereḡerena. Hahehisi gini-gunana: Rara$h$,
     $h$A Farao lalona na dounu auka, ia ese se kamonai henidia, Iehova ena hereva heḡereḡerena.$h$),
    -- EXO 8:19: Hahehisi ihahanina: Lao
    ('e5c5f10e-01c7-4d72-bd8a-76c8493558a1'::uuid, $h$Bena hari mea taudia ese Farao a hamaoroa, eto, Ina na Dirave imana kwakikwakina. A Farao lalona ma e auka, se kamonai henidia, Iehova ese e gwauraia heḡereḡerena. Hahehisi ihahanina: Lao$h$,
     $h$Bena hari mea taudia ese Farao a hamaoroa, eto, Ina na Dirave imana kwakikwakina. A Farao lalona ma e auka, se kamonai henidia, Iehova ese e gwauraia heḡereḡerena.$h$),
    -- EXO 9:7: Hahehisi ihatauratoina: Iohururu
    ('397e49b3-3b73-4b5c-a1b1-b3dd9c916455'::uuid, $h$Bena Farao ena hesiai taudia ese hereva e mailaia, Israel taudia edia seri ai ḡau ta se mase. A Farao ese lalona ma e ha-aukaia, Heberu taudia se kahudia nege. Hahehisi ihatauratoina: Iohururu$h$,
     $h$Bena Farao ena hesiai taudia ese hereva e mailaia, Israel taudia edia seri ai ḡau ta se mase. A Farao ese lalona ma e ha-aukaia, Heberu taudia se kahudia nege.$h$),
    -- EXO 9:12: Hahehisi ihahituna: Medu hetarina
    ('43d1ca32-2655-48a0-870b-d7f6110eda28'::uuid, $h$A Iehova ese Frao lalona ma e ha-aukaia, bena ia ese se kamonai henidia, Iehova ese Mose e hamaoroa guna heḡereḡerena. Hahehisi ihahituna: Medu hetarina$h$,
     $h$A Iehova ese Frao lalona ma e ha-aukaia, bena ia ese se kamonai henidia, Iehova ese Mose e hamaoroa guna heḡereḡerena.$h$),
    -- EXO 9:12: Hahehisi ihahituna: Medu hetarina
    ('905daee6-7d5d-4b93-b290-c79091c716fd'::uuid, $h$A Iehova ese Frao lalona ma e ha-aukaia, bena ia ese se kamonai henidia, Iehova ese Mose e hamaoroa guna heḡereḡerena. Hahehisi ihahituna: Medu hetarina$h$,
     $h$A Iehova ese Frao lalona ma e ha-aukaia, bena ia ese se kamonai henidia, Iehova ese Mose e hamaoroa guna heḡereḡerena.$h$),
    -- EXO 10:20: Hahehisi ihataurahanai-tana: Dibura masemase
    ('9eb15da3-cb7a-4e0c-9157-1d1e33651231'::uuid, $h$A Iehova ese Farao lalona ma e ha-aukaia, bena Israel taudia se kahudia nege. Hahehisi ihataurahanai-tana: Dibura masemase$h$,
     $h$A Iehova ese Farao lalona ma e ha-aukaia, bena Israel taudia se kahudia nege.$h$),
    -- EXO 10:20: Hahehisi ihataurahanai-tana: Dibura masemase
    ('ca2e43b4-65d3-4823-81ba-394e8fd7cd7c'::uuid, $h$A Iehova ese Farao lalona ma e ha-aukaia, bena Israel taudia se kahudia nege. Hahehisi ihataurahanai-tana: Dibura masemase$h$,
     $h$A Iehova ese Farao lalona ma e ha-aukaia, bena Israel taudia se kahudia nege.$h$),
    -- EXO 12:28: Hahehisi ihagwautana: Maruane roboadia ihamasedia
    ('2324d089-013e-415b-846e-bee32234f65e'::uuid, $h$Bena Israel taudia na ela, Mose bona Aaron e haduadia heḡereḡerena unu mo e kara toma. Hahehisi ihagwautana: Maruane roboadia ihamasedia$h$,
     $h$Bena Israel taudia na ela, Mose bona Aaron e haduadia heḡereḡerena unu mo e kara toma.$h$),
    -- EXO 15:21: Israel taudia ranu e masedia
    ('377048e0-9008-4580-8e34-e6092cb7d765'::uuid, $h$Bena Miriama ese tatau edia ane davana e halou henidia, ane e abia, eto, Ane avabia, Iehova ena, badina be ia na vada e kwalimu herea; Hosi bona e gui tauna davara ai vada e tahodia dobi. Israel taudia ranu e masedia$h$,
     $h$Bena Miriama ese tatau edia ane davana e halou henidia, ane e abia, eto, Ane avabia, Iehova ena, badina be ia na vada e kwalimu herea; Hosi bona e gui tauna davara ai vada e tahodia dobi.$h$),
    -- EXO 17:7: Tuari e vara
    ('243493cb-1af6-4bd3-9d97-2b9bcc4ab563'::uuid, $h$Bena una gabu ladana e hatoa Masa bona Meriba, badina be Israel taudia e ḡadeḡade, bona Iehova e dibaḡania, eto “Iehova na dekedekeda ai eiva lasi?” Tuari e vara$h$,
     $h$Bena una gabu ladana e hatoa Masa bona Meriba, badina be Israel taudia e ḡadeḡade, bona Iehova e dibaḡania, eto “Iehova na dekedekeda ai eiva lasi?”$h$),
    -- EXO 17:7: Tuari e vara
    ('269107f5-b235-43dd-bb2e-b4ce3a10d5b2'::uuid, $h$Bena una gabu ladana e hatoa Masa bona Meriba, badina be Israel taudia e ḡadeḡade, bona Iehova e dibaḡania, eto “Iehova na dekedekeda ai eiva lasi?” Tuari e vara$h$,
     $h$Bena una gabu ladana e hatoa Masa bona Meriba, badina be Israel taudia e ḡadeḡade, bona Iehova e dibaḡania, eto “Iehova na dekedekeda ai eiva lasi?”$h$),
    -- EXO 17:7: Tuari e vara
    ('9f4490a5-46c1-4da7-804c-3bf37fa05687'::uuid, $h$Bena una gabu ladana e hatoa Masa bona Meriba, badina be Israel taudia e ḡadeḡade, bona Iehova e dibaḡania, eto “Iehova na dekedekeda ai eiva lasi?” Tuari e vara$h$,
     $h$Bena una gabu ladana e hatoa Masa bona Meriba, badina be Israel taudia e ḡadeḡade, bona Iehova e dibaḡania, eto “Iehova na dekedekeda ai eiva lasi?”$h$),
    -- EXO 17:7: Tuari e vara
    ('a81c40a3-7bc2-4d1f-9424-b10e87f814da'::uuid, $h$Bena una gabu ladana e hatoa Masa bona Meriba, badina be Israel taudia e ḡadeḡade, bona Iehova e dibaḡania, eto “Iehova na dekedekeda ai eiva lasi?” Tuari e vara$h$,
     $h$Bena una gabu ladana e hatoa Masa bona Meriba, badina be Israel taudia e ḡadeḡade, bona Iehova e dibaḡania, eto “Iehova na dekedekeda ai eiva lasi?”$h$),
    -- EXO 17:7: Tuari e vara
    ('cd950ade-d2da-4295-81f2-c4c496d1fbeb'::uuid, $h$Bena una gabu ladana e hatoa Masa bona Meriba, badina be Israel taudia e ḡadeḡade, bona Iehova e dibaḡania, eto “Iehova na dekedekeda ai eiva lasi?” Tuari e vara$h$,
     $h$Bena una gabu ladana e hatoa Masa bona Meriba, badina be Israel taudia e ḡadeḡade, bona Iehova e dibaḡania, eto “Iehova na dekedekeda ai eiva lasi?”$h$),
    -- EXO 17:7: Tuari e vara
    ('ff98ea87-47b5-4287-a6c2-9f9f159387f2'::uuid, $h$Bena una gabu ladana e hatoa Masa bona Meriba, badina be Israel taudia e ḡadeḡade, bona Iehova e dibaḡania, eto “Iehova na dekedekeda ai eiva lasi?” Tuari e vara$h$,
     $h$Bena una gabu ladana e hatoa Masa bona Meriba, badina be Israel taudia e ḡadeḡade, bona Iehova e dibaḡania, eto “Iehova na dekedekeda ai eiva lasi?”$h$),
    -- EXO 21:11: Ala-ala Taravatudia
    ('08738451-3dff-417e-9c7e-704e20343abf'::uuid, $h$A ini ḡau ai baine hadabua, ia na baine kahua nege, asi davana. Ala-ala Taravatudia$h$,
     $h$A ini ḡau ai baine hadabua, ia na baine kahua nege, asi davana.$h$),
    -- EXO 24:11: Mose Sinai ororona ai e dara dae
    ('170aeba3-8d5d-4d2d-a49d-ead892ca4ddb'::uuid, $h$Ia imana na Israeltau-badadia latadiai se ato kau; idia ese Dirava e itaia, bena e aniani, ranu e inua danu. Mose Sinai ororona ai e dara dae$h$,
     $h$Ia imana na Israeltau-badadia latadiai se ato kau; idia ese Dirava e itaia, bena e aniani, ranu e inua danu.$h$),
    -- EXO 25:22: Pata Helaḡana
    ('c6a6be1c-6662-4081-8593-df4388c917f0'::uuid, $h$Unuseni ai baita hedavari: ikaruhi daenai, taravatu mauana latanai e miamu kerubidia raruosi padadia amo, lau ese baina hereva henimu; haheḡani iboudiai, Israel taudia ba henidia ḡaudia, na baina hadibalaimu. Pata Helaḡana$h$,
     $h$Unuseni ai baita hedavari: ikaruhi daenai, taravatu mauana latanai e miamu kerubidia raruosi padadia amo, lau ese baina hereva henimu; haheḡani iboudiai, Israel taudia ba henidia ḡaudia, na baina hadibalaimu.$h$),
    -- EXO 25:22: Pata Helaḡana
    ('e87fefc9-0607-4495-aa1e-e4c0fec7eb7e'::uuid, $h$Unuseni ai baita hedavari: ikaruhi daenai, taravatu mauana latanai e miamu kerubidia raruosi padadia amo, lau ese baina hereva henimu; haheḡani iboudiai, Israel taudia ba henidia ḡaudia, na baina hadibalaimu. Pata Helaḡana$h$,
     $h$Unuseni ai baita hedavari: ikaruhi daenai, taravatu mauana latanai e miamu kerubidia raruosi padadia amo, lau ese baina hereva henimu; haheḡani iboudiai, Israel taudia ba henidia ḡaudia, na baina hadibalaimu.$h$),
    -- EXO 25:30: Lamepa Patana
    ('99fa331d-46fa-452b-8f60-d9c9cde6154b'::uuid, $h$Nega iboudiai flaoa helaḡana na una pata latanai baine hedabara lau vairagu ai. Lamepa Patana$h$,
     $h$Nega iboudiai flaoa helaḡana na una pata latanai baine hedabara lau vairagu ai.$h$),
    -- EXO 27:8: Maḡu Helaḡana
    ('14ee5d9e-e03c-4561-bab5-a5373a1f5964'::uuid, $h$Ihaboulaina patana na maua na heto ba karaia, harana na reirei amo baine hekou. Vada ba karaia hari ina ororo ai emu ai vada eme hedinarai heḡereḡerena. Maḡu Helaḡana$h$,
     $h$Ihaboulaina patana na maua na heto ba karaia, harana na reirei amo baine hekou. Vada ba karaia hari ina ororo ai emu ai vada eme hedinarai heḡereḡerena.$h$),
    -- EXO 27:8: Maḡu Helaḡana
    ('87525559-653a-4fb3-9d61-e3fff1131c41'::uuid, $h$Ihaboulaina patana na maua na heto ba karaia, harana na reirei amo baine hekou. Vada ba karaia hari ina ororo ai emu ai vada eme hedinarai heḡereḡerena. Maḡu Helaḡana$h$,
     $h$Ihaboulaina patana na maua na heto ba karaia, harana na reirei amo baine hekou. Vada ba karaia hari ina ororo ai emu ai vada eme hedinarai heḡereḡerena.$h$),
    -- EXO 27:19: Lamepa Helaḡana
    ('98eb85d1-78e9-4f69-a055-a8a9a905206c'::uuid, $h$Dubu kohuna idoinai na auri labora-labora amo bae kara; dubu ikokodia bona maḡu ikokodia danu iboudiai na auri labora-labora ikokodia mo. Lamepa Helaḡana$h$,
     $h$Dubu kohuna idoinai na auri labora-labora amo bae kara; dubu ikokodia bona maḡu ikokodia danu iboudiai na auri labora-labora ikokodia mo.$h$),
    -- EXO 30:16: Hahelaḡa Taudia Ihaḡoevadia
    ('b04de8b4-6f0e-4d74-a3a7-68e7a44a157a'::uuid, $h$Ina kara dika itahundia monina na Israel taudia ediai bavabia, hebou kalagana monina ai ba halaoa: ia na helalo-tao ḡauna ai bainela Israel taudia edia, Iehova vairanai, bona emui kara dika itahunidia ḡauna ai bainela. Hahelaḡa Taudia Ihaḡoevadia$h$,
     $h$Ina kara dika itahundia monina na Israel taudia ediai bavabia, hebou kalagana monina ai ba halaoa: ia na helalo-tao ḡauna ai bainela Israel taudia edia, Iehova vairanai, bona emui kara dika itahunidia ḡauna ai bainela.$h$),
    -- EXO 30:21: Dehoro Helaḡana
    ('0da2b50c-2087-4e05-b0ef-f0467fa5b7ff'::uuid, $h$imadia bona aedia bae huri, bae mase garina. Mia-hanaihanai haheḡanina binai, idia edia, Aaron mai rarana ida edia, ela uru idoidiai. Dehoro Helaḡana$h$,
     $h$imadia bona aedia bae huri, bae mase garina. Mia-hanaihanai haheḡanina binai, idia edia, Aaron mai rarana ida edia, ela uru idoidiai.$h$),
    -- EXO 31:11: Dina Helaḡa Imatauraina
    ('8ece79cf-80bd-4973-9e50-00e9610506bf'::uuid, $h$bona ihorodia dehorona, bona muramura mai bonadia, gabu helaḡana ena. Na haḡanilaimu ḡaudia iboudiai na idia ese bae kara. Dina Helaḡa Imatauraina$h$,
     $h$bona ihorodia dehorona, bona muramura mai bonadia, gabu helaḡana ena. Na haḡanilaimu ḡaudia iboudiai na idia ese bae kara.$h$),
    -- EXO 31:17: Taravatu Nadidia
    ('923acc2b-f505-4b91-b153-76c3bbeeff51'::uuid, $h$Ia na mia hanaihanai toana, lau bona umui Israel taumai padadai. Badina be Iehova ese guba bona tanobada e karadia, dina tauratoi lalodiai, a dina ihahituna ai e laḡa ani, bona e kara ḡaudia e moalelai. Taravatu Nadidia$h$,
     $h$Ia na mia hanaihanai toana, lau bona umui Israel taumai padadai. Badina be Iehova ese guba bona tanobada e karadia, dina tauratoi lalodiai, a dina ihahituna ai e laḡa ani, bona e kara ḡaudia e moalelai.$h$),
    -- EXO 33:6: Hebou Kalagana
    ('532aa9dc-51bf-4823-bc43-876c4893bac6'::uuid, $h$Taunabunai, Israel taudia na Horeb ororona ai edia herehera ḡaudia e kokidia oho, asie kara lou. Hebou Kalagana$h$,
     $h$Taunabunai, Israel taudia na Horeb ororona ai edia herehera ḡaudia e kokidia oho, asie kara lou.$h$),
    -- EXO 33:11: Mose ena noinoi
    ('8e1195d5-6918-445d-a6cf-6ee11b1817c7'::uuid, $h$Una negana ai Iehova bona Mose e hevaira heheni bona e hereva heheni, tau ta ese turana ida bae hereva hereva na heto. Bena Mose na taruha e lou henia negana ai, ena hesiai tauna, Iosua Nunu, tau eregabe ta, ese hebou kalagana se rakatania. Mose ena noinoi$h$,
     $h$Una negana ai Iehova bona Mose e hevaira heheni bona e hereva heheni, tau ta ese turana ida bae hereva hereva na heto. Bena Mose na taruha e lou henia negana ai, ena hesiai tauna, Iosua Nunu, tau eregabe ta, ese hebou kalagana se rakatania.$h$),
    -- EXO 36:1: Kalaga Helaḡana e karaia
    ('1c076e9f-6d45-4d61-b0c3-9adbb4b01dc4'::uuid, $h$Benaini, Besalele bona Oholiab bona karakara taudia, Iehova ese lalo-parara bona aonega vada e henidia taudia, iboudiai ese ḡaukara bae matamaia, dubu do bae karaioa, Iehova ena hahedua heḡereḡeredia. Kalaga Helaḡana e karaia$h$,
     $h$Benaini, Besalele bona Oholiab bona karakara taudia, Iehova ese lalo-parara bona aonega vada e henidia taudia, iboudiai ese ḡaukara bae matamaia, dubu do bae karaioa, Iehova ena hahedua heḡereḡeredia.$h$),
    -- EXO 37:16: Lamepa Patana e karaia
    ('2432b09f-b7b6-48fd-be7b-57404c9e30e4'::uuid, $h$Pata ḡaudia danu, mereki bona nau bona bio bona udu-ahudia keheredia, iboudiai na gold namo-hereana amo e kara. Lamepa Patana e karaia$h$,
     $h$Pata ḡaudia danu, mereki bona nau bona bio bona udu-ahudia keheredia, iboudiai na gold namo-hereana amo e kara.$h$),
    -- EXO 37:16: Lamepa Patana e karaia
    ('f90bd4ba-1219-4189-b826-487cf4257f41'::uuid, $h$Pata ḡaudia danu, mereki bona nau bona bio bona udu-ahudia keheredia, iboudiai na gold namo-hereana amo e kara. Lamepa Patana e karaia$h$,
     $h$Pata ḡaudia danu, mereki bona nau bona bio bona udu-ahudia keheredia, iboudiai na gold namo-hereana amo e kara.$h$),
    -- EXO 38:8: Maḡu Helaḡana e karaia
    ('5e1dd195-f0d6-4a80-9ce4-2fa2d0ce86eb'::uuid, $h$Dihu ta danu auri labora-labora amo e karaia, mai ihahelai-kauna ḡauna, ia danu auri labora-labora. Hari dihu mai ihahelai-kauna ḡauna ida na hebou kalagana iduarana ai e gimava hahinedia edia auri labora-labora hevarivaridia amo e karaia. Maḡu Helaḡana e karaia$h$,
     $h$Dihu ta danu auri labora-labora amo e karaia, mai ihahelai-kauna ḡauna, ia danu auri labora-labora. Hari dihu mai ihahelai-kauna ḡauna ida na hebou kalagana iduarana ai e gimava hahinedia edia auri labora-labora hevarivaridia amo e karaia.$h$),
    -- EXO 38:8: Maḡu Helaḡana e karaia
    ('74510dca-cfcc-4e49-92e6-ba2491f5afc9'::uuid, $h$Dihu ta danu auri labora-labora amo e karaia, mai ihahelai-kauna ḡauna, ia danu auri labora-labora. Hari dihu mai ihahelai-kauna ḡauna ida na hebou kalagana iduarana ai e gimava hahinedia edia auri labora-labora hevarivaridia amo e karaia. Maḡu Helaḡana e karaia$h$,
     $h$Dihu ta danu auri labora-labora amo e karaia, mai ihahelai-kauna ḡauna, ia danu auri labora-labora. Hari dihu mai ihahelai-kauna ḡauna ida na hebou kalagana iduarana ai e gimava hahinedia edia auri labora-labora hevarivaridia amo e karaia.$h$),
    -- EXO 39:31: Gaukara e haḡuḡurua
    ('69c5948b-3854-4908-aa48-6080d7e27623'::uuid, $h$Bena varo vaiurina kwara iḡeḡelaina dabuana ai e turia kau, Iehova ese Mose e haḡania heḡereḡerena. Gaukara e haḡuḡurua$h$,
     $h$Bena varo vaiurina kwara iḡeḡelaina dabuana ai e turia kau, Iehova ese Mose e haḡania heḡereḡerena.$h$),
    -- EZK 3:15: Israel igimana tauna
    ('1497c2d9-19b5-4d65-a288-0b5be85256a9'::uuid, $h$Bena dauhai e hanohodia taudia dekediai na kau, Telabibi ai; idia na Kebara sinavaina isena ai e nohova. Bena unuseni ai na helai, idia bogaragidiai, laumagu na e daure ela bona dina hitu e ore. Israel igimana tauna$h$,
     $h$Bena dauhai e hanohodia taudia dekediai na kau, Telabibi ai; idia na Kebara sinavaina isena ai e nohova. Bena unuseni ai na helai, idia bogaragidiai, laumagu na e daure ela bona dina hitu e ore.$h$),
    -- EZK 25:14: Peroveta herevana Filistia taudia latadiai
    ('c9df69d2-0965-415a-832e-e9a9920a7635'::uuid, $h$Egu hahedava-heni na Edom latanai baina atoa kau, egu bese Israel taudia imadia ai; Edom ai bae ḡaukara, egu badu bona egu badu-ḡaraḡara heḡereḡeredia ai; bona egu hahedava-heni bae diba. Ḡaubada Iehova na e herevamu. Peroveta herevana Filistia taudia latadiai$h$,
     $h$Egu hahedava-heni na Edom latanai baina atoa kau, egu bese Israel taudia imadia ai; Edom ai bae ḡaukara, egu badu bona egu badu-ḡaraḡara heḡereḡeredia ai; bona egu hahedava-heni bae diba. Ḡaubada Iehova na e herevamu.$h$),
    -- EZK 28:10: Rohe-ahu Turo pavapavana lat 0 lai
    ('5a3fe29c-da4c-4071-98ab-92c1f15074f8'::uuid, $h$Asie peritomedia taudia edia mase ai ba mase, idau taudia imadia ai. Ḡaubada Iehova na e tomu, Lau vada na hereva. Rohe-ahu Turo pavapavana lat 0 lai$h$,
     $h$Asie peritomedia taudia edia mase ai ba mase, idau taudia imadia ai. Ḡaubada Iehova na e tomu, Lau vada na hereva.$h$),
    -- EZK 43:9: Dubu bona Ihaboulaina Patana Taravatudia
    ('b3274e0d-6faf-431a-8e06-939639e956fb'::uuid, $h$Harihari edia kaivakuku itomadihohenidia bona edia pavapava tau-anidia masedia na bae negedia daure, bena lau na idia bogaragidiai baina noho hanaihanai. Dubu bona Ihaboulaina Patana Taravatudia$h$,
     $h$Harihari edia kaivakuku itomadihohenidia bona edia pavapava tau-anidia masedia na bae negedia daure, bena lau na idia bogaragidiai baina noho hanaihanai.$h$),
    -- EZK 45:12: Boubou bona Aria
    ('c1b38669-b7a9-4d23-bec3-4b4ed3eb5bfd'::uuid, $h$Sekele na gera ruahui heḡereḡeredia; sekele ima be sekele anidia korikoridia inta ba heni, bona sekele gwauta be sekele anidia korikoridia gwauta ba heni. Emui mina lalonai sekele bae imahui. Boubou bona Aria$h$,
     $h$Sekele na gera ruahui heḡereḡeredia; sekele ima be sekele anidia korikoridia inta ba heni, bona sekele gwauta be sekele anidia korikoridia gwauta ba heni. Emui mina lalonai sekele bae imahui.$h$),
    -- EZR 3:7: Dubu ihagini-louna e matamaia
    ('c30d46b0-debd-42fb-b3d3-e7eb4c4f2b49'::uuid, $h$Taunabunai, idia ese nadi iḡaukaralaidia taudia bona kamuta taudia na moni e henidia; bona aniani bona inuinu ḡaudia bona dehoro na Sidono bona Turo taudia e henidia, sida audia na Lebanon amo bae lasilaidia kone ai bona lopa ai bae atodia na davana, Kurese, Parasa pavapavana, ena gwau-maoro heḡereḡerena. Dubu ihagini-louna e matamaia$h$,
     $h$Taunabunai, idia ese nadi iḡaukaralaidia taudia bona kamuta taudia na moni e henidia; bona aniani bona inuinu ḡaudia bona dehoro na Sidono bona Turo taudia e henidia, sida audia na Lebanon amo bae lasilaidia kone ai bona lopa ai bae atodia na davana, Kurese, Parasa pavapavana, ena gwau-maoro heḡereḡerena.$h$),
    -- GEN 2:3: Adam
    ('0602de64-ab65-412f-88cf-322aac11bc99'::uuid, $h$Bena Dirava ese dina ihahituna e hanamoa bona e hahelaḡaia: badina be una dina ai ena ḡaukara iboudiai e ato diho, e laḡa ani. Adam$h$,
     $h$Bena Dirava ese dina ihahituna e hanamoa bona e hahelaḡaia: badina be una dina ai ena ḡaukara iboudiai e ato diho, e laḡa ani.$h$),
    -- GEN 2:3: Adam
    ('0752fa94-03ac-40c2-adef-80cd095b97fe'::uuid, $h$Bena Dirava ese dina ihahituna e hanamoa bona e hahelaḡaia: badina be una dina ai ena ḡaukara iboudiai e ato diho, e laḡa ani. Adam$h$,
     $h$Bena Dirava ese dina ihahituna e hanamoa bona e hahelaḡaia: badina be una dina ai ena ḡaukara iboudiai e ato diho, e laḡa ani.$h$),
    -- GEN 2:3: Adam
    ('07dccbb1-9214-4e49-9dc6-c137e1ea3b6e'::uuid, $h$Bena Dirava ese dina ihahituna e hanamoa bona e hahelaḡaia: badina be una dina ai ena ḡaukara iboudiai e ato diho, e laḡa ani. Adam$h$,
     $h$Bena Dirava ese dina ihahituna e hanamoa bona e hahelaḡaia: badina be una dina ai ena ḡaukara iboudiai e ato diho, e laḡa ani.$h$),
    -- GEN 2:3: Adam
    ('32a8146f-5849-4c99-b608-e0d8fc50bc4d'::uuid, $h$Bena Dirava ese dina ihahituna e hanamoa bona e hahelaḡaia: badina be una dina ai ena ḡaukara iboudiai e ato diho, e laḡa ani. Adam$h$,
     $h$Bena Dirava ese dina ihahituna e hanamoa bona e hahelaḡaia: badina be una dina ai ena ḡaukara iboudiai e ato diho, e laḡa ani.$h$),
    -- GEN 2:3: Adam
    ('cc725740-478f-43de-b0ac-0398a9c525a6'::uuid, $h$Bena Dirava ese dina ihahituna e hanamoa bona e hahelaḡaia: badina be una dina ai ena ḡaukara iboudiai e ato diho, e laḡa ani. Adam$h$,
     $h$Bena Dirava ese dina ihahituna e hanamoa bona e hahelaḡaia: badina be una dina ai ena ḡaukara iboudiai e ato diho, e laḡa ani.$h$),
    -- GEN 9:17: Noa ena Mauri dokona
    ('712a9f98-e711-42f0-b6d2-a9598bf5bce9'::uuid, $h$Dirava ese Noa ma e hamaoroa, eto, Lauegu ai bona mauri ḡaudia iboudiai ediai na atuamu taravatuna toana binai. Noa ena Mauri dokona$h$,
     $h$Dirava ese Noa ma e hamaoroa, eto, Lauegu ai bona mauri ḡaudia iboudiai ediai na atuamu taravatuna toana binai.$h$),
    -- GEN 9:17: Noa ena Mauri dokona
    ('b6895f4c-1b98-4f4e-b3bc-965b83feee17'::uuid, $h$Dirava ese Noa ma e hamaoroa, eto, Lauegu ai bona mauri ḡaudia iboudiai ediai na atuamu taravatuna toana binai. Noa ena Mauri dokona$h$,
     $h$Dirava ese Noa ma e hamaoroa, eto, Lauegu ai bona mauri ḡaudia iboudiai ediai na atuamu taravatuna toana binai.$h$),
    -- GEN 9:17: Noa ena Mauri dokona
    ('e0ed38b5-78e6-4bdd-81c4-be2b7d55d798'::uuid, $h$Dirava ese Noa ma e hamaoroa, eto, Lauegu ai bona mauri ḡaudia iboudiai ediai na atuamu taravatuna toana binai. Noa ena Mauri dokona$h$,
     $h$Dirava ese Noa ma e hamaoroa, eto, Lauegu ai bona mauri ḡaudia iboudiai ediai na atuamu taravatuna toana binai.$h$),
    -- GEN 11:9: Abram senena
    ('309d9027-1820-47ec-80f2-f5be7b8d1252'::uuid, $h$Taunabunai, una gabu ladana e hatoa Babel; badina be unuseni ai Iehova ese taunimanima edia gado e ha-idaua, bona unu amo ia ese e hakarohodia rohoroho, tanobada kahadia idoidiai. Abram senena$h$,
     $h$Taunabunai, una gabu ladana e hatoa Babel; badina be unuseni ai Iehova ese taunimanima edia gado e ha-idaua, bona unu amo ia ese e hakarohodia rohoroho, tanobada kahadia idoidiai.$h$),
    -- GEN 11:9: Abram senena
    ('54a82524-8487-4e64-b7d3-af2c67c16460'::uuid, $h$Taunabunai, una gabu ladana e hatoa Babel; badina be unuseni ai Iehova ese taunimanima edia gado e ha-idaua, bona unu amo ia ese e hakarohodia rohoroho, tanobada kahadia idoidiai. Abram senena$h$,
     $h$Taunabunai, una gabu ladana e hatoa Babel; badina be unuseni ai Iehova ese taunimanima edia gado e ha-idaua, bona unu amo ia ese e hakarohodia rohoroho, tanobada kahadia idoidiai.$h$),
    -- GEN 11:9: Abram senena
    ('e041decf-49d1-4026-8d75-cc326215e8ea'::uuid, $h$Taunabunai, una gabu ladana e hatoa Babel; badina be unuseni ai Iehova ese taunimanima edia gado e ha-idaua, bona unu amo ia ese e hakarohodia rohoroho, tanobada kahadia idoidiai. Abram senena$h$,
     $h$Taunabunai, una gabu ladana e hatoa Babel; badina be unuseni ai Iehova ese taunimanima edia gado e ha-idaua, bona unu amo ia ese e hakarohodia rohoroho, tanobada kahadia idoidiai.$h$),
    -- GEN 12:9: Abram Aigupto ela
    ('6dae9fd8-8ffc-4e43-8552-27c2062a7faa'::uuid, $h$Ma eha laolao, diho kahana ela. Abram Aigupto ela$h$,
     $h$Ma eha laolao, diho kahana ela.$h$),
    -- GEN 12:9: Abram Aigupto ela
    ('f5f51401-677d-48c9-a2a1-a5f468329672'::uuid, $h$Ma eha laolao, diho kahana ela. Abram Aigupto ela$h$,
     $h$Ma eha laolao, diho kahana ela.$h$),
    -- GEN 14:16: Abram bona Melkisedek
    ('59d370f7-e0ea-486d-81d4-4333616cb0cc'::uuid, $h$Kohu idoinai e abia lou, bona vavana Lot mai ena kohu ida, bona hahine, bona hanua taudia loḡora. Abram bona Melkisedek$h$,
     $h$Kohu idoinai e abia lou, bona vavana Lot mai ena kohu ida, bona hahine, bona hanua taudia loḡora.$h$),
    -- GEN 14:16: Abram bona Melkisedek
    ('a216f41d-7b68-49ac-bb2f-c0e48838a924'::uuid, $h$Kohu idoinai e abia lou, bona vavana Lot mai ena kohu ida, bona hahine, bona hanua taudia loḡora. Abram bona Melkisedek$h$,
     $h$Kohu idoinai e abia lou, bona vavana Lot mai ena kohu ida, bona hahine, bona hanua taudia loḡora.$h$),
    -- GEN 21:21: Abraham bona Abimelek e herohemaino
    ('635f570d-b14c-4ce9-8153-69d8bd77fe65'::uuid, $h$Ia na Paran tano ḡaḡaena ai e nohova; bena sinana ese Aigupto hane-ulatona ta e abia, ia baine adavaia. Abraham bona Abimelek e herohemaino$h$,
     $h$Ia na Paran tano ḡaḡaena ai e nohova; bena sinana ese Aigupto hane-ulatona ta e abia, ia baine adavaia.$h$),
    -- GEN 21:21: Abraham bona Abimelek e herohemaino
    ('9884f438-8651-47c3-871f-a1e673be8c7f'::uuid, $h$Ia na Paran tano ḡaḡaena ai e nohova; bena sinana ese Aigupto hane-ulatona ta e abia, ia baine adavaia. Abraham bona Abimelek e herohemaino$h$,
     $h$Ia na Paran tano ḡaḡaena ai e nohova; bena sinana ese Aigupto hane-ulatona ta e abia, ia baine adavaia.$h$),
    -- GEN 21:21: Abraham bona Abimelek e herohemaino
    ('e37dc388-e4aa-4c46-b485-751563a0ec99'::uuid, $h$Ia na Paran tano ḡaḡaena ai e nohova; bena sinana ese Aigupto hane-ulatona ta e abia, ia baine adavaia. Abraham bona Abimelek e herohemaino$h$,
     $h$Ia na Paran tano ḡaḡaena ai e nohova; bena sinana ese Aigupto hane-ulatona ta e abia, ia baine adavaia.$h$),
    -- GEN 24:67: s. 22. sekele kahana = 8 grams sisivana; sekele gwauta = 160 grams sisivana
    ('4b7c0ddd-6486-41c9-8421-d0d59e45f350'::uuid, $h$Bena Isaak ese Rebeka e hakaua lao, sinana Sara ena dabua rumana ai e hakaua vareai, e adavaia. Bena ia iura-henina ese lalona e hamarumarua, sinana taina e taiva negadia ai. s. 22. sekele kahana = 8 grams sisivana; sekele gwauta = 160 grams sisivana$h$,
     $h$Bena Isaak ese Rebeka e hakaua lao, sinana Sara ena dabua rumana ai e hakaua vareai, e adavaia. Bena ia iura-henina ese lalona e hamarumarua, sinana taina e taiva negadia ai.$h$),
    -- GEN 24:67: s. 22. sekele kahana = 8 grams sisivana; sekele gwauta = 160 grams sisivana
    ('79cb695b-fe68-4f34-9d11-80e5c1418f28'::uuid, $h$Bena Isaak ese Rebeka e hakaua lao, sinana Sara ena dabua rumana ai e hakaua vareai, e adavaia. Bena ia iura-henina ese lalona e hamarumarua, sinana taina e taiva negadia ai. s. 22. sekele kahana = 8 grams sisivana; sekele gwauta = 160 grams sisivana$h$,
     $h$Bena Isaak ese Rebeka e hakaua lao, sinana Sara ena dabua rumana ai e hakaua vareai, e adavaia. Bena ia iura-henina ese lalona e hamarumarua, sinana taina e taiva negadia ai.$h$),
    -- GEN 24:67: s. 22. sekele kahana = 8 grams sisivana; sekele gwauta = 160 grams sisivana
    ('83ed01a7-4b1f-4654-9ff0-70f4e17d92fd'::uuid, $h$Bena Isaak ese Rebeka e hakaua lao, sinana Sara ena dabua rumana ai e hakaua vareai, e adavaia. Bena ia iura-henina ese lalona e hamarumarua, sinana taina e taiva negadia ai. s. 22. sekele kahana = 8 grams sisivana; sekele gwauta = 160 grams sisivana$h$,
     $h$Bena Isaak ese Rebeka e hakaua lao, sinana Sara ena dabua rumana ai e hakaua vareai, e adavaia. Bena ia iura-henina ese lalona e hamarumarua, sinana taina e taiva negadia ai.$h$),
    -- GEN 24:67: s. 22. sekele kahana = 8 grams sisivana; sekele gwauta = 160 grams sisivana
    ('b33e9ffa-aa73-489d-849b-e7b218f2c2fe'::uuid, $h$Bena Isaak ese Rebeka e hakaua lao, sinana Sara ena dabua rumana ai e hakaua vareai, e adavaia. Bena ia iura-henina ese lalona e hamarumarua, sinana taina e taiva negadia ai. s. 22. sekele kahana = 8 grams sisivana; sekele gwauta = 160 grams sisivana$h$,
     $h$Bena Isaak ese Rebeka e hakaua lao, sinana Sara ena dabua rumana ai e hakaua vareai, e adavaia. Bena ia iura-henina ese lalona e hamarumarua, sinana taina e taiva negadia ai.$h$),
    -- GEN 24:67: s. 22. sekele kahana = 8 grams sisivana; sekele gwauta = 160 grams sisivana
    ('c005e6e0-577e-421f-a96f-34b37955f0cb'::uuid, $h$Bena Isaak ese Rebeka e hakaua lao, sinana Sara ena dabua rumana ai e hakaua vareai, e adavaia. Bena ia iura-henina ese lalona e hamarumarua, sinana taina e taiva negadia ai. s. 22. sekele kahana = 8 grams sisivana; sekele gwauta = 160 grams sisivana$h$,
     $h$Bena Isaak ese Rebeka e hakaua lao, sinana Sara ena dabua rumana ai e hakaua vareai, e adavaia. Bena ia iura-henina ese lalona e hamarumarua, sinana taina e taiva negadia ai.$h$),
    -- GEN 25:6: Abraham e mase
    ('77915ab7-0dbb-4f95-9fa8-4c6e4e111603'::uuid, $h$A adavana oredia natudia na maurina ai e harihari henidia, bena e siaidia karoho, mairiveina kahana ai bae hanoho. Abraham e mase$h$,
     $h$A adavana oredia natudia na maurina ai e harihari henidia, bena e siaidia karoho, mairiveina kahana ai bae hanoho.$h$),
    -- GEN 25:6: Abraham e mase
    ('e3e4c9d4-1a97-4635-bcdd-c83c5d4e2b4f'::uuid, $h$A adavana oredia natudia na maurina ai e harihari henidia, bena e siaidia karoho, mairiveina kahana ai bae hanoho. Abraham e mase$h$,
     $h$A adavana oredia natudia na maurina ai e harihari henidia, bena e siaidia karoho, mairiveina kahana ai bae hanoho.$h$),
    -- GEN 25:18: Esau bona Iakob e vara
    ('18934b55-ba5c-4b10-b98f-307ebaa40a0f'::uuid, $h$Edia tano na Havila ela bona Suru, Aigupto mairiveina kahana ai; tadikakadia iboudiai idia mo mairiveina kahana korikori ai e nohova. Esau bona Iakob e vara$h$,
     $h$Edia tano na Havila ela bona Suru, Aigupto mairiveina kahana ai; tadikakadia iboudiai idia mo mairiveina kahana korikori ai e nohova.$h$),
    -- GEN 25:18: Esau bona Iakob e vara
    ('67cabef7-fbd7-4fb9-97a6-af4a26e8eedb'::uuid, $h$Edia tano na Havila ela bona Suru, Aigupto mairiveina kahana ai; tadikakadia iboudiai idia mo mairiveina kahana korikori ai e nohova. Esau bona Iakob e vara$h$,
     $h$Edia tano na Havila ela bona Suru, Aigupto mairiveina kahana ai; tadikakadia iboudiai idia mo mairiveina kahana korikori ai e nohova.$h$),
    -- GEN 25:18: Esau bona Iakob e vara
    ('92f4fe30-bad1-49f1-8cda-432f6e361116'::uuid, $h$Edia tano na Havila ela bona Suru, Aigupto mairiveina kahana ai; tadikakadia iboudiai idia mo mairiveina kahana korikori ai e nohova. Esau bona Iakob e vara$h$,
     $h$Edia tano na Havila ela bona Suru, Aigupto mairiveina kahana ai; tadikakadia iboudiai idia mo mairiveina kahana korikori ai e nohova.$h$),
    -- GEN 26:22: Isaak Beresieba ai
    ('07273dff-ce7e-46ae-a4e2-06fbb1d97de5'::uuid, $h$Unu amo ma e raka oho bena guri ta ma e ḡeia. Una na asie heatulaia; taunabunai ladana e hatoa Rehoboto; badina be ia eto, Iehova ese gabu ta vada e lailaia eda, iniseni ai baita noho namonamo. Isaak Beresieba ai$h$,
     $h$Unu amo ma e raka oho bena guri ta ma e ḡeia. Una na asie heatulaia; taunabunai ladana e hatoa Rehoboto; badina be ia eto, Iehova ese gabu ta vada e lailaia eda, iniseni ai baita noho namonamo.$h$),
    -- GEN 26:22: Isaak Beresieba ai
    ('78d8c2da-5652-4c9c-a27b-fc963eef5432'::uuid, $h$Unu amo ma e raka oho bena guri ta ma e ḡeia. Una na asie heatulaia; taunabunai ladana e hatoa Rehoboto; badina be ia eto, Iehova ese gabu ta vada e lailaia eda, iniseni ai baita noho namonamo. Isaak Beresieba ai$h$,
     $h$Unu amo ma e raka oho bena guri ta ma e ḡeia. Una na asie heatulaia; taunabunai ladana e hatoa Rehoboto; badina be ia eto, Iehova ese gabu ta vada e lailaia eda, iniseni ai baita noho namonamo.$h$),
    -- GEN 26:33: Esau e headava
    ('6662d93c-d5c2-42d6-8276-a0a86f98d1a7'::uuid, $h$Bena una ranu gabuna ladana e hatoa Siba, taunabunai una hanua ladana na Bere-sieba ema bona harihari. Esau e headava$h$,
     $h$Bena una ranu gabuna ladana e hatoa Siba, taunabunai una hanua ladana na Bere-sieba ema bona harihari.$h$),
    -- GEN 28:9: Iakob ena nihi
    ('46b41b64-e69b-44c2-aa1d-7601c3c9c730'::uuid, $h$Taunabunai, Esau na Ismael dekena ela, Ismael Abraham natuna kekenina Mahalata, Nebaioto taihuna, e adavaia; ḡau tamona, adavana gunadia raruosi nonoho. Iakob ena nihi$h$,
     $h$Taunabunai, Esau na Ismael dekena ela, Ismael Abraham natuna kekenina Mahalata, Nebaioto taihuna, e adavaia; ḡau tamona, adavana gunadia raruosi nonoho.$h$),
    -- GEN 28:9: Iakob ena nihi
    ('f02c37bb-31dc-42ee-8976-9803f573bd01'::uuid, $h$Taunabunai, Esau na Ismael dekena ela, Ismael Abraham natuna kekenina Mahalata, Nebaioto taihuna, e adavaia; ḡau tamona, adavana gunadia raruosi nonoho. Iakob ena nihi$h$,
     $h$Taunabunai, Esau na Ismael dekena ela, Ismael Abraham natuna kekenina Mahalata, Nebaioto taihuna, e adavaia; ḡau tamona, adavana gunadia raruosi nonoho.$h$),
    -- GEN 30:24: Iakob ese ravana e koia
    ('6df1b340-332f-4c9f-ae7f-ee32768c3985'::uuid, $h$Bena ladana e hatoa Iosef; eto, Iehova ese ma ta bema henigu bema namo. Iakob ese ravana e koia$h$,
     $h$Bena ladana e hatoa Iosef; eto, Iehova ese ma ta bema henigu bema namo.$h$),
    -- GEN 30:24: Iakob ese ravana e koia
    ('ace88f3c-fdbf-41cf-893e-34319000436d'::uuid, $h$Bena ladana e hatoa Iosef; eto, Iehova ese ma ta bema henigu bema namo. Iakob ese ravana e koia$h$,
     $h$Bena ladana e hatoa Iosef; eto, Iehova ese ma ta bema henigu bema namo.$h$),
    -- GEN 41:45: Iosef Aigupto lohiana
    ('b2918f05-9538-4563-80ce-3125f19caedb'::uuid, $h$Bena Farao ese Iosef ladana e hatoa Safenat-panea; Asenat danu e henia, baine adavaia; una Asenat na Ono ena hahelaḡa tauna, ladana Potifera, natuna. Bena Iosef na Aigupto tanona idoinai e rakaia hanai. Iosef Aigupto lohiana$h$,
     $h$Bena Farao ese Iosef ladana e hatoa Safenat-panea; Asenat danu e henia, baine adavaia; una Asenat na Ono ena hahelaḡa tauna, ladana Potifera, natuna. Bena Iosef na Aigupto tanona idoinai e rakaia hanai.$h$),
    -- GEN 41:45: Iosef Aigupto lohiana
    ('c596ef4a-2e61-4df5-86c0-6eef4aec0385'::uuid, $h$Bena Farao ese Iosef ladana e hatoa Safenat-panea; Asenat danu e henia, baine adavaia; una Asenat na Ono ena hahelaḡa tauna, ladana Potifera, natuna. Bena Iosef na Aigupto tanona idoinai e rakaia hanai. Iosef Aigupto lohiana$h$,
     $h$Bena Farao ese Iosef ladana e hatoa Safenat-panea; Asenat danu e henia, baine adavaia; una Asenat na Ono ena hahelaḡa tauna, ladana Potifera, natuna. Bena Iosef na Aigupto tanona idoinai e rakaia hanai.$h$),
    -- GEN 41:45: Iosef Aigupto lohiana
    ('e7c7f602-d3ef-4f3a-b45e-c0e4705f0534'::uuid, $h$Bena Farao ese Iosef ladana e hatoa Safenat-panea; Asenat danu e henia, baine adavaia; una Asenat na Ono ena hahelaḡa tauna, ladana Potifera, natuna. Bena Iosef na Aigupto tanona idoinai e rakaia hanai. Iosef Aigupto lohiana$h$,
     $h$Bena Farao ese Iosef ladana e hatoa Safenat-panea; Asenat danu e henia, baine adavaia; una Asenat na Ono ena hahelaḡa tauna, ladana Potifera, natuna. Bena Iosef na Aigupto tanona idoinai e rakaia hanai.$h$),
    -- GEN 41:45: Iosef Aigupto lohiana
    ('eeeb1023-d039-4730-90b5-326249e95d0d'::uuid, $h$Bena Farao ese Iosef ladana e hatoa Safenat-panea; Asenat danu e henia, baine adavaia; una Asenat na Ono ena hahelaḡa tauna, ladana Potifera, natuna. Bena Iosef na Aigupto tanona idoinai e rakaia hanai. Iosef Aigupto lohiana$h$,
     $h$Bena Farao ese Iosef ladana e hatoa Safenat-panea; Asenat danu e henia, baine adavaia; una Asenat na Ono ena hahelaḡa tauna, ladana Potifera, natuna. Bena Iosef na Aigupto tanona idoinai e rakaia hanai.$h$),
    -- GEN 47:12: Aigupto taudia e ogogamiva
    ('dacdd0b3-cea5-4081-83e9-a172838936d7'::uuid, $h$Bena Iosef ese tamana bona tadikakana bona tamana ena orea taudia iboudiai e ubudia, ruma ta ta taudia adia e henidia. Aigupto taudia e ogogamiva$h$,
     $h$Bena Iosef ese tamana bona tadikakana bona tamana ena orea taudia iboudiai e ubudia, ruma ta ta taudia adia e henidia.$h$),
    -- HAB 2:5: Kara dika taudia iḡonaḡonalaidia
    ('0fcfe4a8-5c7f-47ec-a2df-6d76d704f9af'::uuid, $h$Ina danu, vine ranuna na mai ena hekoi, bona hekokoroku tauna na basine noho daudau. Ena mata-ganigani na mai lababana, Mase Gabuna na heto, mase na heto, ia na se honumu. Basileia iboudiai na e gogodiamu, ena; bona bese iboudiai na e haboudiamu, ia sibona ena. Kara dika taudia iḡonaḡonalaidia$h$,
     $h$Ina danu, vine ranuna na mai ena hekoi, bona hekokoroku tauna na basine noho daudau. Ena mata-ganigani na mai lababana, Mase Gabuna na heto, mase na heto, ia na se honumu. Basileia iboudiai na e gogodiamu, ena; bona bese iboudiai na e haboudiamu, ia sibona ena.$h$),
    -- HAB 2:5: Kara dika taudia iḡonaḡonalaidia
    ('8b259dfd-0254-486f-b4e6-b2ccf2a95b3a'::uuid, $h$Ina danu, vine ranuna na mai ena hekoi, bona hekokoroku tauna na basine noho daudau. Ena mata-ganigani na mai lababana, Mase Gabuna na heto, mase na heto, ia na se honumu. Basileia iboudiai na e gogodiamu, ena; bona bese iboudiai na e haboudiamu, ia sibona ena. Kara dika taudia iḡonaḡonalaidia$h$,
     $h$Ina danu, vine ranuna na mai ena hekoi, bona hekokoroku tauna na basine noho daudau. Ena mata-ganigani na mai lababana, Mase Gabuna na heto, mase na heto, ia na se honumu. Basileia iboudiai na e gogodiamu, ena; bona bese iboudiai na e haboudiamu, ia sibona ena.$h$),
    -- HAG 2:9: Sisiba herevadia
    ('7d9b1119-f3ae-4678-8a0a-0e54ef32db4e'::uuid, $h$Iehova Sabaota na e tomu, Ina dubu hairaina gabena ese hailaina gunana baine hereaia, bena ina gabu ena noho-namo baina habadaia. Iehova Sabaota na e herevamu. Sisiba herevadia$h$,
     $h$Iehova Sabaota na e tomu, Ina dubu hairaina gabena ese hailaina gunana baine hereaia, bena ina gabu ena noho-namo baina habadaia. Iehova Sabaota na e herevamu.$h$),
    -- HEB 1:3: Iesu ese aneru e hereadiamu
    ('95f73a76-42f1-457b-bf3c-da4c3db71d23'::uuid, $h$Ia bunai Dirava hairaina diari-diarina bona anitarana ihaheḡereḡerena; ia bunai ḡau iboudiai e abi isimu, ena siahu herevadia amo; ia sibona ese eda kara dika e haḡoeva vaitani, bena Herea Mikamika idibana kahana ai vada e helai, guba ai. Iesu ese aneru e hereadiamu$h$,
     $h$Ia bunai Dirava hairaina diari-diarina bona anitarana ihaheḡereḡerena; ia bunai ḡau iboudiai e abi isimu, ena siahu herevadia amo; ia sibona ese eda kara dika e haḡoeva vaitani, bena Herea Mikamika idibana kahana ai vada e helai, guba ai.$h$),
    -- HOS 6:11: Israel ena kara havara bona ena daḡedaḡe
    ('18e81fd3-62f2-41ee-9779-a26ede850d9d'::uuid, $h$Iuda e, oi danu, itaboromu negana vada e gwauraia guna. Israel ena kara havara bona ena daḡedaḡe Egu bese taudia edia noho-namo bama havaraia lou nato negana ai,$h$,
     $h$Iuda e, oi danu, itaboromu negana vada e gwauraia guna. Egu bese taudia edia noho-namo bama havaraia lou nato negana ai,$h$),
    -- HOS 11:11: Efraim igwau-henina
    ('6adb9d29-184b-4578-b7a1-097635f8d668'::uuid, $h$mai kudou-hetahadia ida Aigupto amo baema, manu na heheto, Asuria tanona amo baema, pune na heheto; bena ma baina haloudia, edia noho gabudia korikori baela. Iehova na e herevamu. Efraim igwau-henina$h$,
     $h$mai kudou-hetahadia ida Aigupto amo baema, manu na heheto, Asuria tanona amo baema, pune na heheto; bena ma baina haloudia, edia noho gabudia korikori baela. Iehova na e herevamu.$h$),
    -- ISA 1:9: Helao kerehai
    ('9e27392d-73d9-45f9-80bf-d23b4a5f60e4'::uuid, $h$Iehova Saboata ese kwabukwabuda basinema hamaurida, ita na Sodoma heḡereḡerena ai baitama noho, bona Gomora heḡereḡerena ai baitama hahelao. Helao kerehai$h$,
     $h$Iehova Saboata ese kwabukwabuda basinema hamaurida, ita na Sodoma heḡereḡerena ai baitama noho, bona Gomora heḡereḡerena ai baitama hahelao.$h$),
    -- ISA 1:9: Helao kerehai
    ('a4d7ec78-ad3c-4ff7-b632-0954cc0edb20'::uuid, $h$Iehova Saboata ese kwabukwabuda basinema hamaurida, ita na Sodoma heḡereḡerena ai baitama noho, bona Gomora heḡereḡerena ai baitama hahelao. Helao kerehai$h$,
     $h$Iehova Saboata ese kwabukwabuda basinema hamaurida, ita na Sodoma heḡereḡerena ai baitama noho, bona Gomora heḡereḡerena ai baitama hahelao.$h$),
    -- ISA 1:20: Siona ihahemaorohenina bona ihamaurina
    ('8c6b4c54-8b57-4ead-ae59-1e6e743ebaf2'::uuid, $h$a boma gwau edeede bona boma daḡedaḡe, dare ese bema alamui mamase; badina be Iehova uduna vada e hereva. Siona ihahemaorohenina bona ihamaurina$h$,
     $h$a boma gwau edeede bona boma daḡedaḡe, dare ese bema alamui mamase; badina be Iehova uduna vada e hereva.$h$),
    -- ISA 2:4: Heaḡi taudia ihahemaoro-henidia
    ('56c2157a-ec90-4abf-b605-2db2baa2beb4'::uuid, $h$Ia ese bese idau-idau padadiai baine hahemaoro, bona hahemaoro herevadia na taunimanima loḡora baine gwaurai henidia; bena idia ese edia dare bae hododia, ruarua auridia ai bae halaodia, bona edia io bae hododia, kwama-kwama kaiadia ae bae halaodia; bese ta ese dare basine veri lasi, bese ta ihadikana totona, bona tuari daladia basie hahedibalai lou. Heaḡi taudia ihahemaoro-henidia$h$,
     $h$Ia ese bese idau-idau padadiai baine hahemaoro, bona hahemaoro herevadia na taunimanima loḡora baine gwaurai henidia; bena idia ese edia dare bae hododia, ruarua auridia ai bae halaodia, bona edia io bae hododia, kwama-kwama kaiadia ae bae halaodia; bese ta ese dare basine veri lasi, bese ta ihadikana totona, bona tuari daladia basie hahedibalai lou.$h$),
    -- ISA 2:4: Heaḡi taudia ihahemaoro-henidia
    ('5b70528e-8888-43ae-834b-beacd444dc04'::uuid, $h$Ia ese bese idau-idau padadiai baine hahemaoro, bona hahemaoro herevadia na taunimanima loḡora baine gwaurai henidia; bena idia ese edia dare bae hododia, ruarua auridia ai bae halaodia, bona edia io bae hododia, kwama-kwama kaiadia ae bae halaodia; bese ta ese dare basine veri lasi, bese ta ihadikana totona, bona tuari daladia basie hahedibalai lou. Heaḡi taudia ihahemaoro-henidia$h$,
     $h$Ia ese bese idau-idau padadiai baine hahemaoro, bona hahemaoro herevadia na taunimanima loḡora baine gwaurai henidia; bena idia ese edia dare bae hododia, ruarua auridia ai bae halaodia, bona edia io bae hododia, kwama-kwama kaiadia ae bae halaodia; bese ta ese dare basine veri lasi, bese ta ihadikana totona, bona tuari daladia basie hahedibalai lou.$h$),
    -- ISA 3:15: Siona kekenidia ihahemaoro-henidia
    ('5a01ecb7-bc4f-4301-af68-0747072a0905'::uuid, $h$Dahaka dainai egu bese taudia o moimoilaidiamu, bona ogoḡami taudia vairadia o moidia taomu? Ḡaubada, Iehova Sabaota, unu e gwau tomamu. Siona kekenidia ihahemaoro-henidia$h$,
     $h$Dahaka dainai egu bese taudia o moimoilaidiamu, bona ogoḡami taudia vairadia o moidia taomu? Ḡaubada, Iehova Sabaota, unu e gwau tomamu.$h$),
    -- ISA 7:9: Emanuel
    ('f07a1b6e-fb3f-4142-b5da-d6af5e58672e'::uuid, $h$Bona Efraim kwarana na Samaria, bona Samaria kwarana na Remalia natuna. Bema basio kamonai, momokani umui na basio gini tutuka-tutuka. Emanuel$h$,
     $h$Bona Efraim kwarana na Samaria, bona Samaria kwarana na Remalia natuna. Bema basio kamonai, momokani umui na basio gini tutuka-tutuka.$h$),
    -- ISA 8:10: Iehova garina ba gari
    ('c932b4e3-8e7d-4cf1-984a-27a03b16124e'::uuid, $h$Ba henega bou, to ḡau ta basine vara; ba hereva, to emui hereva basine gini; badina be Dirava na ai dekedekemai ai. Iehova garina ba gari$h$,
     $h$Ba henega bou, to ḡau ta basine vara; ba hereva, to emui hereva basine gini; badina be Dirava na ai dekedekemai ai.$h$),
    -- ISA 9:7: Iehova ena badu Israel latanai
    ('c14d7bde-a672-4cea-8ae9-403a06aa2a38'::uuid, $h$Ena heregu ihabadana bona maino daladia na basie doko, David ena terono bona ena basileia latadiai, baine haginia bona baine ha-aukaia totona, mai hahemaoro ḡoevaḡoeva bona mai kara maoromaoro ida, hari ina nega ela hanaihanai. Ina na Iehova Sabaota ena ura-kwalimu ese baine karaia. Iehova ena badu Israel latanai$h$,
     $h$Ena heregu ihabadana bona maino daladia na basie doko, David ena terono bona ena basileia latadiai, baine haginia bona baine ha-aukaia totona, mai hahemaoro ḡoevaḡoeva bona mai kara maoromaoro ida, hari ina nega ela hanaihanai. Ina na Iehova Sabaota ena ura-kwalimu ese baine karaia.$h$),
    -- ISA 14:23: Asuria baine darere
    ('cf2c4afe-fccc-4a7d-901b-a464dc3a6a66'::uuid, $h$Iehova Sabaota na e tomu, Lau ese migu ena gabu bona gohugohu gabuna ai baina halaoa, bona hahebua-tari idarona amo baina daroa. Asuria baine darere$h$,
     $h$Iehova Sabaota na e tomu, Lau ese migu ena gabu bona gohugohu gabuna ai baina halaoa, bona hahebua-tari idarona amo baina daroa.$h$),
    -- ISA 21:10: Maduna metauna Duma latanai
    ('1ed24e37-c096-48f6-b58b-92a03fb37c9c'::uuid, $h$Bamogu e, e kwadimu bona e tapomu taumu e, Iehova Sabaota, Israel Diravana, ena amo vada na kamonai ḡauna na oi na hahedinarai henimumu. Maduna metauna Duma latanai$h$,
     $h$Bamogu e, e kwadimu bona e tapomu taumu e, Iehova Sabaota, Israel Diravana, ena amo vada na kamonai ḡauna na oi na hahedinarai henimumu.$h$),
    -- ISA 21:10: Maduna metauna Duma latanai
    ('3e8d9d86-7be7-4369-bad4-ac4b6969d704'::uuid, $h$Bamogu e, e kwadimu bona e tapomu taumu e, Iehova Sabaota, Israel Diravana, ena amo vada na kamonai ḡauna na oi na hahedinarai henimumu. Maduna metauna Duma latanai$h$,
     $h$Bamogu e, e kwadimu bona e tapomu taumu e, Iehova Sabaota, Israel Diravana, ena amo vada na kamonai ḡauna na oi na hahedinarai henimumu.$h$),
    -- ISA 22:14: Eliakimi ese Sebna gabuna baine abia
    ('c88cbff7-2891-4503-92f8-677744038c42'::uuid, $h$Iehova Sabaota ese vada e hahedinarai henigu, taiagu ai vada e hereva, eto: Ina emui kara havara na basine hegwau tao ela bona ba mase. Ḡaubada, Iehova Sabaota, na unu e gwau tomamu. Eliakimi ese Sebna gabuna baine abia$h$,
     $h$Iehova Sabaota ese vada e hahedinarai henigu, taiagu ai vada e hereva, eto: Ina emui kara havara na basine hegwau tao ela bona ba mase. Ḡaubada, Iehova Sabaota, na unu e gwau tomamu.$h$),
    -- ISA 25:5: Iehova ena ororo
    ('9b94eadf-011b-45a4-a82f-a7caa137a25c'::uuid, $h$eiava siahu ḡaraḡarana tano kaukauna ai na heto. Oi ese idau taudia edia heloḡo-heloḡo o tuiamu; siahu na ori ese e hakerukeruamu na heto, asi edia hebogahisi taudia edia ane na unu o tuia tomamu. Iehova ena ororo$h$,
     $h$eiava siahu ḡaraḡarana tano kaukauna ai na heto. Oi ese idau taudia edia heloḡo-heloḡo o tuiamu; siahu na ori ese e hakerukeruamu na heto, asi edia hebogahisi taudia edia ane na unu o tuia tomamu.$h$),
    -- ISA 25:5: Iehova ena ororo
    ('b65028f7-526b-4240-8a5c-d4d16bb55b94'::uuid, $h$eiava siahu ḡaraḡarana tano kaukauna ai na heto. Oi ese idau taudia edia heloḡo-heloḡo o tuiamu; siahu na ori ese e hakerukeruamu na heto, asi edia hebogahisi taudia edia ane na unu o tuia tomamu. Iehova ena ororo$h$,
     $h$eiava siahu ḡaraḡarana tano kaukauna ai na heto. Oi ese idau taudia edia heloḡo-heloḡo o tuiamu; siahu na ori ese e hakerukeruamu na heto, asi edia hebogahisi taudia edia ane na unu o tuia tomamu.$h$),
    -- ISA 28:6: Ierusalem isisiba-henina
    ('1a11b5d8-8ea3-43a0-adbc-a9e2a4e0dbae'::uuid, $h$hahemaoro ḡoevaḡoeva laumana ai bainela, hahemaoro tauna enai, bona goada ai bainela, tuari na hanua ikoukouna amo e halouamu taudia ediai. Ierusalem isisiba-henina$h$,
     $h$hahemaoro ḡoevaḡoeva laumana ai bainela, hahemaoro tauna enai, bona goada ai bainela, tuari na hanua ikoukouna amo e halouamu taudia ediai.$h$),
    -- ISA 29:8: Israel ena mata-kepulu bona ena koikoi
    ('4871f0db-39e7-4c83-8711-0d445751c404'::uuid, $h$Hitolo tauna na heto, e nihimu bena ena nihi ai e anianimu, a mai hitolona ida e nogamu; eiava ranu-mase tauna na heto, e nihimu bena ena nihi ai ranu e inumu, a mai manorina bona mai ranu-masena ida e nogamu, Siona ororona e tuari heniamu besedia loḡora iboudiai na unu mo bae heto. Israel ena mata-kepulu bona ena koikoi$h$,
     $h$Hitolo tauna na heto, e nihimu bena ena nihi ai e anianimu, a mai hitolona ida e nogamu; eiava ranu-mase tauna na heto, e nihimu bena ena nihi ai ranu e inumu, a mai manorina bona mai ranu-masena ida e nogamu, Siona ororona e tuari heniamu besedia loḡora iboudiai na unu mo bae heto.$h$),
    -- ISA 29:8: Israel ena mata-kepulu bona ena koikoi
    ('908aa372-a21f-45e9-aade-0c35e674def7'::uuid, $h$Hitolo tauna na heto, e nihimu bena ena nihi ai e anianimu, a mai hitolona ida e nogamu; eiava ranu-mase tauna na heto, e nihimu bena ena nihi ai ranu e inumu, a mai manorina bona mai ranu-masena ida e nogamu, Siona ororona e tuari heniamu besedia loḡora iboudiai na unu mo bae heto. Israel ena mata-kepulu bona ena koikoi$h$,
     $h$Hitolo tauna na heto, e nihimu bena ena nihi ai e anianimu, a mai hitolona ida e nogamu; eiava ranu-mase tauna na heto, e nihimu bena ena nihi ai ranu e inumu, a mai manorina bona mai ranu-masena ida e nogamu, Siona ororona e tuari heniamu besedia loḡora iboudiai na unu mo bae heto.$h$),
    -- ISA 29:16: Israel ihamaurina
    ('edf05bac-f224-4192-b97e-cfc49b013848'::uuid, $h$Umui ese ḡau o karuhi hebubumu! Uro ikarana tauna na raro bae gwauraia a? E karaia ḡauna ese ikarana tauna baine herevalaia, baineto “Ia ese asine karagu”, a? Eiava oromana e henia ḡauna ese oromana ihenina tauna baine herevalaia, baineto “Ia na asi ena lalo-parara”, a? Israel ihamaurina$h$,
     $h$Umui ese ḡau o karuhi hebubumu! Uro ikarana tauna na raro bae gwauraia a? E karaia ḡauna ese ikarana tauna baine herevalaia, baineto “Ia ese asine karagu”, a? Eiava oromana e henia ḡauna ese oromana ihenina tauna baine herevalaia, baineto “Ia na asi ena lalo-parara”, a?$h$),
    -- ISA 30:17: Dirava ena gwauhamata ena bese taudia edia
    ('170c4588-a99e-4588-bad1-8d91606d51e2'::uuid, $h$Taunimanima daha-ta bae heau, tau tamona ese baine halalaḡadia dainai; bona tatau laima ese bae halalaḡamui dainai umui na ba heau; ela bona ba noho, au-tubua ta ororo dorina ai eiava pepe ta ororo ai na heto. Dirava ena gwauhamata ena bese taudia edia$h$,
     $h$Taunimanima daha-ta bae heau, tau tamona ese baine halalaḡadia dainai; bona tatau laima ese bae halalaḡamui dainai umui na ba heau; ela bona ba noho, au-tubua ta ororo dorina ai eiava pepe ta ororo ai na heto.$h$),
    -- ISA 30:17: Dirava ena gwauhamata ena bese taudia edia
    ('bdd424c1-822f-4044-a0a0-42699fca2db2'::uuid, $h$Taunimanima daha-ta bae heau, tau tamona ese baine halalaḡadia dainai; bona tatau laima ese bae halalaḡamui dainai umui na ba heau; ela bona ba noho, au-tubua ta ororo dorina ai eiava pepe ta ororo ai na heto. Dirava ena gwauhamata ena bese taudia edia$h$,
     $h$Taunimanima daha-ta bae heau, tau tamona ese baine halalaḡadia dainai; bona tatau laima ese bae halalaḡamui dainai umui na ba heau; ela bona ba noho, au-tubua ta ororo dorina ai eiava pepe ta ororo ai na heto.$h$),
    -- ISA 30:26: Iehova ena hahemaoro Asuria latanai
    ('1ab1608b-3236-4048-965c-51c26aca6e44'::uuid, $h$Ina danu, hua diarina na dina diarina heḡereḡerena ai bainela, bona dina diarina na baine habadaia hahitu, dina hitu diaridia heḡereḡeredia, Iehova ese ena bese taudia edia hisi gabudia baine kumidia bona ena hebota amo vada e havaradia berodia baine hanamodia dinana ai. Iehova ena hahemaoro Asuria latanai$h$,
     $h$Ina danu, hua diarina na dina diarina heḡereḡerena ai bainela, bona dina diarina na baine habadaia hahitu, dina hitu diaridia heḡereḡeredia, Iehova ese ena bese taudia edia hisi gabudia baine kumidia bona ena hebota amo vada e havaradia berodia baine hanamodia dinana ai.$h$),
    -- ISA 32:8: Ierusalem hahinedia isisiba-henidia
    ('656297b8-f48d-470a-b8fb-937c8e3523ed'::uuid, $h$A lalo-ḡoevadae tauna ese kara ḡoeva-daedia e lalo hatalaimu, bona kara ḡoeva-daedia daidiai e ginimu. Ierusalem hahinedia isisiba-henidia$h$,
     $h$A lalo-ḡoevadae tauna ese kara ḡoeva-daedia e lalo hatalaimu, bona kara ḡoeva-daedia daidiai e ginimu.$h$),
    -- ISA 32:8: Ierusalem hahinedia isisiba-henidia
    ('912967e5-0a40-47dc-9ff9-e066172c7bda'::uuid, $h$A lalo-ḡoevadae tauna ese kara ḡoeva-daedia e lalo hatalaimu, bona kara ḡoeva-daedia daidiai e ginimu. Ierusalem hahinedia isisiba-henidia$h$,
     $h$A lalo-ḡoevadae tauna ese kara ḡoeva-daedia e lalo hatalaimu, bona kara ḡoeva-daedia daidiai e ginimu.$h$),
    -- ISA 42:9: Iehova i'imodaina
    ('57dba345-6020-4bc4-b19c-64946f0d6ffa'::uuid, $h$A itaia, ḡau gunadia vada e vara, harihari ḡau matamatadia na gwaurai hedinaraimu; idia na do asie hedinarai negana ai na hamaorolaimuimu. Iehova i'imodaina$h$,
     $h$A itaia, ḡau gunadia vada e vara, harihari ḡau matamatadia na gwaurai hedinaraimu; idia na do asie hedinarai negana ai na hamaorolaimuimu.$h$),
    -- ISA 44:20: Iehova na Israel Ihamaurina
    ('a3fe1c08-e4aa-4233-a557-0173c223704a'::uuid, $h$Ia na kahu e animu; ena lalo-duhu ese vada ehakaua kerere. Asi ena dala sibona baine hahemauri, eiava baineto “Imagu idibana ai koikoi na dia mia a?” Iehova na Israel Ihamaurina$h$,
     $h$Ia na kahu e animu; ena lalo-duhu ese vada ehakaua kerere. Asi ena dala sibona baine hahemauri, eiava baineto “Imagu idibana ai koikoi na dia mia a?”$h$),
    -- ISA 50:3: Iehova ena hesiai tauna ena kamonai
    ('3d6719e7-5de3-4a72-9fcb-0096b0d843ac'::uuid, $h$Guba na korema-korema ai na hadabualaiamu, bona puse dabuadia ai na ḡovalaiamu. Iehova ena hesiai tauna ena kamonai$h$,
     $h$Guba na korema-korema ai na hadabualaiamu, bona puse dabuadia ai na ḡovalaiamu.$h$),
    -- ISA 56:8: Israel edia kaivakuku irevadia
    ('93929915-4745-4c34-87a3-a32395551315'::uuid, $h$Ḡaubada Iehova, Israel bogaragina amo e luludia oho taudia e haboudiamu Diravana, e tomu “Lau ese ma haida ienai baina haboudia, na haboudia guna taudia ida”. Israel edia kaivakuku irevadia$h$,
     $h$Ḡaubada Iehova, Israel bogaragina amo e luludia oho taudia e haboudiamu Diravana, e tomu “Lau ese ma haida ienai baina haboudia, na haboudia guna taudia ida”.$h$),
    -- ISA 58:12: Dina Helaḡa ibadinana
    ('47ed76f2-8f6a-4493-bd31-095b10a56b45'::uuid, $h$Emui hanua gunadia, vada e vahu ḡaudia, na bae hahegini lou, bona uru momo ba havaradia matama; bae gwauraimu “e ḡiḡi dobi gabuna ibanina tauna”, bona “taunimanima edia noho gabudia ihagini-loudia tauna”. Dina Helaḡa ibadinana$h$,
     $h$Emui hanua gunadia, vada e vahu ḡaudia, na bae hahegini lou, bona uru momo ba havaradia matama; bae gwauraimu “e ḡiḡi dobi gabuna ibanina tauna”, bona “taunimanima edia noho gabudia ihagini-loudia tauna”.$h$),
    -- ISA 58:12: Dina Helaḡa ibadinana
    ('7091c655-2f42-45b4-a178-1193f036a730'::uuid, $h$Emui hanua gunadia, vada e vahu ḡaudia, na bae hahegini lou, bona uru momo ba havaradia matama; bae gwauraimu “e ḡiḡi dobi gabuna ibanina tauna”, bona “taunimanima edia noho gabudia ihagini-loudia tauna”. Dina Helaḡa ibadinana$h$,
     $h$Emui hanua gunadia, vada e vahu ḡaudia, na bae hahegini lou, bona uru momo ba havaradia matama; bae gwauraimu “e ḡiḡi dobi gabuna ibanina tauna”, bona “taunimanima edia noho gabudia ihagini-loudia tauna”.$h$),
    -- ISA 63:6: Iehova ena hahenamo Israel enai
    ('2aa80d14-24af-43d5-b5bc-24b0d76208f3'::uuid, $h$Egu badu ai bese idau-idau na moidia tari, egu badu ḡaraḡara amo na hakekerodia, bona edia mauri raradia na tano ai na hahebubudia. Iehova ena hahenamo Israel enai$h$,
     $h$Egu badu ai bese idau-idau na moidia tari, egu badu ḡaraḡara amo na hakekerodia, bona edia mauri raradia na tano ai na hahebubudia.$h$),
    -- ISA 63:14: Hebogahisi bona Hekaha inoilaina
    ('4bca2e44-a9fe-4e5a-866e-ab100755be83'::uuid, $h$boromakau koura ai e hekei dihomu na heheto, Iehova ena Lauma ese laḡadia e ha-ani. Taunabunai oi ese emu bese taudia o hakaudia, lada herea-daena sibomu bavabia totona. Hebogahisi bona Hekaha inoilaina$h$,
     $h$boromakau koura ai e hekei dihomu na heheto, Iehova ena Lauma ese laḡadia e ha-ani. Taunabunai oi ese emu bese taudia o hakaudia, lada herea-daena sibomu bavabia totona.$h$),
    -- JAS 1:11: Dirava na se dibaḡanidamu
    ('4097b61a-a486-446b-8c00-bb17f547f608'::uuid, $h$Badina be dina e tata dae rohamu, e ḡaraḡaramu, rei e hamaraiamu; bena huahuana e hehuhumu, bona ita-itana namona e oremu. Taḡa tauna danu unu baine lao bubuni toma. Dirava na se dibaḡanidamu$h$,
     $h$Badina be dina e tata dae rohamu, e ḡaraḡaramu, rei e hamaraiamu; bena huahuana e hehuhumu, bona ita-itana namona e oremu. Taḡa tauna danu unu baine lao bubuni toma.$h$),
    -- JDG 6:10: Iehova ese Gideon e boiria
    ('185e2afb-f80c-42a2-9876-a03dd5becb38'::uuid, $h$bena na hamaoromui, nato “Lau na Iehova, emui Dirava; Amoro taudia, edia tano ai o nohomu taudia, edia dirava na basio toma henidia diho”. A eregu asio kamonai. Iehova ese Gideon e boiria$h$,
     $h$bena na hamaoromui, nato “Lau na Iehova, emui Dirava; Amoro taudia, edia tano ai o nohomu taudia, edia dirava na basio toma henidia diho”. A eregu asio kamonai.$h$),
    -- JDG 6:24: Gideon ese Baal ena ihaboulaina patana e ḡiḡia dobi
    ('b857977d-4628-4d20-a68e-886832618f08'::uuid, $h$Bena Gideon ese ihaboulaina patana auta e larebaia unuseni ai, Iehova ena; ladana e hatoa Iehova-salom. Ia na doini mia, Ofra ai, Abiesere taudia edia tano ai, ema bona hari. Gideon ese Baal ena ihaboulaina patana e ḡiḡia dobi$h$,
     $h$Bena Gideon ese ihaboulaina patana auta e larebaia unuseni ai, Iehova ena; ladana e hatoa Iehova-salom. Ia na doini mia, Ofra ai, Abiesere taudia edia tano ai, ema bona hari.$h$),
    -- JDG 6:32: Midian taudia e tore isi
    ('2a732218-f3ac-4c13-bee3-6de8685d9779'::uuid, $h$Taunabunai, hari Gideon na una dina ai e nemaia Ierubu-baal (anina be “Baal ese baine ala-ala henia”), badina be ia ese Baal ena ihaboulaina patana e ḡiḡia dobi. Midian taudia e tore isi$h$,
     $h$Taunabunai, hari Gideon na una dina ai e nemaia Ierubu-baal (anina be “Baal ese baine ala-ala henia”), badina be ia ese Baal ena ihaboulaina patana e ḡiḡia dobi.$h$),
    -- JDG 6:35: Dirava ese toa ta Gideon e henia
    ('d77cae08-0113-439e-b984-147a845834be'::uuid, $h$Ia ese gwaukau taudia danu e siaidia, Manase tanona idoinai, Manase taudia iboudiai e boiridia, ia murina amo baela. Ma gwaukau taudia haida danu e siaidia, Asere taudia bona Sebulun taudia bona liapatali taudia dekediai; bena idia na e tore isi, bamodia dekedia ela. Dirava ese toa ta Gideon e henia$h$,
     $h$Ia ese gwaukau taudia danu e siaidia, Manase tanona idoinai, Manase taudia iboudiai e boiridia, ia murina amo baela. Ma gwaukau taudia haida danu e siaidia, Asere taudia bona Sebulun taudia bona liapatali taudia dekediai; bena idia na e tore isi, bamodia dekedia ela.$h$),
    -- JDG 7:14: Gideon e heḡaeḡae
    ('a33d4de7-52e8-4723-8539-d75b5080c61d'::uuid, $h$Bena bamoma na e haere, eto, Ina na Gideon Ioasa, Israel tauna, ena dare; Dirava ese Midian mai ena orea idoinai ida ia imana ai vada e atodia. Gideon e heḡaeḡae$h$,
     $h$Bena bamoma na e haere, eto, Ina na Gideon Ioasa, Israel tauna, ena dare; Dirava ese Midian mai ena orea idoinai ida ia imana ai vada e atodia.$h$),
    -- JDG 7:18: Gideon e tuari
    ('2b25f0ce-a5c8-4393-99f9-2238b5bea566'::uuid, $h$Lau mai bamogu iboudiai ida emai kibi baia hiriri negana ai na umui danu emui kibi ba hiriri, edia taruha hegeḡemadai; bena ba lolo, baoto “Iehova bagunai bona Gideon bagunai”. Gideon e tuari$h$,
     $h$Lau mai bamogu iboudiai ida emai kibi baia hiriri negana ai na umui danu emui kibi ba hiriri, edia taruha hegeḡemadai; bena ba lolo, baoto “Iehova bagunai bona Gideon bagunai”.$h$),
    -- JDG 8:21: Gideon na tuari amo e lou
    ('e741fce8-0229-4536-8609-804a209638a6'::uuid, $h$Bena Sebaha bona Salmuna eto, Oi sibomu a tore isi, avalamai mase; tau ta be ena goada heḡereḡerena ai baine kara. Bena Gideon e tore isi, Sebaha bona Salmuna e aladia mase. Bena edia kamelo aiodia iheralaidia mairidia e abi. Gideon na tuari amo e lou$h$,
     $h$Bena Sebaha bona Salmuna eto, Oi sibomu a tore isi, avalamai mase; tau ta be ena goada heḡereḡerena ai baine kara. Bena Gideon e tore isi, Sebaha bona Salmuna e aladia mase. Bena edia kamelo aiodia iheralaidia mairidia e abi.$h$),
    -- JDG 8:21: Gideon na tuari amo e lou
    ('f71d076a-c1c8-4e78-b452-eff90cb5a594'::uuid, $h$Bena Sebaha bona Salmuna eto, Oi sibomu a tore isi, avalamai mase; tau ta be ena goada heḡereḡerena ai baine kara. Bena Gideon e tore isi, Sebaha bona Salmuna e aladia mase. Bena edia kamelo aiodia iheralaidia mairidia e abi. Gideon na tuari amo e lou$h$,
     $h$Bena Sebaha bona Salmuna eto, Oi sibomu a tore isi, avalamai mase; tau ta be ena goada heḡereḡerena ai baine kara. Bena Gideon e tore isi, Sebaha bona Salmuna e aladia mase. Bena edia kamelo aiodia iheralaidia mairidia e abi.$h$),
    -- JDG 9:6: Iotam ena sivarai heḡereḡerena
    ('101fd0ba-110a-45fd-9a4c-9addc5d0c813'::uuid, $h$Bena Sekem taudia iboudiai bona Bete-milo taudia iboudiai na ela, Abimelek e abia dae, Sekem ena oak auna helaḡana badibadinai, edia pavapava ai e halaoa. Iotam ena sivarai heḡereḡerena$h$,
     $h$Bena Sekem taudia iboudiai bona Bete-milo taudia iboudiai na ela, Abimelek e abia dae, Sekem ena oak auna helaḡana badibadinai, edia pavapava ai e halaoa.$h$),
    -- JDG 9:21: Abimelek ena kara
    ('b7801c8f-6ce5-441a-96a6-e36dbff692f3'::uuid, $h$Bena lotam e heau, Bere ela, unuseni ai e nohova, kakana Abimelek garina e gariva dainai. Abimelek ena kara$h$,
     $h$Bena lotam e heau, Bere ela, unuseni ai e nohova, kakana Abimelek garina e gariva dainai.$h$),
    -- JDG 9:49: Abimelek e mase
    ('09c0ed69-d843-4b00-bf63-f69df7725823'::uuid, $h$Taunabunai, idia iboudiai ta ta ena au ena au e raku, ena iḡui ena iḡui e hua, Abimelek murina amo e raka, edia au rakuraku na dubu habana badinai e ato kau. Bena idia ese dubu e ha-araia; taunabunai Sekem kohorona taudia iboudiai na lahi ai e mase. Idia na tatau bona hahine: iboudiai na daha ta sisivana. Abimelek e mase$h$,
     $h$Taunabunai, idia iboudiai ta ta ena au ena au e raku, ena iḡui ena iḡui e hua, Abimelek murina amo e raka, edia au rakuraku na dubu habana badinai e ato kau. Bena idia ese dubu e ha-araia; taunabunai Sekem kohorona taudia iboudiai na lahi ai e mase. Idia na tatau bona hahine: iboudiai na daha ta sisivana.$h$),
    -- JDG 11:33: Iefeta e lou
    ('2d15eec5-d776-41cb-a8ba-b8c2fd2d94dd'::uuid, $h$Bena ia ese e aladia, Aroere amo ela bona Miniti badibadinai. Hanua ruahui e abidia, ela bona Abele-keramim, mai ala-ala bada hereana ida. Taunabunai, Amono taudia vada e darere, Israel taudia vairadiai. Iefeta e lou$h$,
     $h$Bena ia ese e aladia, Aroere amo ela bona Miniti badibadinai. Hanua ruahui e abidia, ela bona Abele-keramim, mai ala-ala bada hereana ida. Taunabunai, Amono taudia vada e darere, Israel taudia vairadiai.$h$),
    -- JDG 11:33: Iefeta e lou
    ('cac41d1c-0ef8-44a1-bbed-8960e5264f3c'::uuid, $h$Bena ia ese e aladia, Aroere amo ela bona Miniti badibadinai. Hanua ruahui e abidia, ela bona Abele-keramim, mai ala-ala bada hereana ida. Taunabunai, Amono taudia vada e darere, Israel taudia vairadiai. Iefeta e lou$h$,
     $h$Bena ia ese e aladia, Aroere amo ela bona Miniti badibadinai. Hanua ruahui e abidia, ela bona Abele-keramim, mai ala-ala bada hereana ida. Taunabunai, Amono taudia vada e darere, Israel taudia vairadiai.$h$),
    -- JDG 16:3: Samson ese Delila e ura henia
    ('7b925876-8f32-4478-96b8-9a715460cf0f'::uuid, $h$A Samson na e hekure ela bona malokihi: bena malokihi ai e tore isi, hanua ikoukouna mai audia ida bona mai ikahidia ida e raḡadia, paḡana ai e huadia lao, ela bona Heberon e vaira henia ororona dorina. Samson ese Delila e ura henia$h$,
     $h$A Samson na e hekure ela bona malokihi: bena malokihi ai e tore isi, hanua ikoukouna mai audia ida bona mai ikahidia ida e raḡadia, paḡana ai e huadia lao, ela bona Heberon e vaira henia ororona dorina.$h$),
    -- JDG 16:5: Samson ese Delila e koia
    ('d1f19fc0-e897-4507-8e09-f667642571d7'::uuid, $h$Bena Filistia lohiadia na una hahine dekena ela, e hereva henia, eto, A koia, ba diba ena goada hereana na ede amo, bona edena dala amo baia hadarerea; bena baia ḡuia bona baia hamanadaia; bena silver monidia daha-ta sinahu-ta baia henimu. Samson ese Delila e koia$h$,
     $h$Bena Filistia lohiadia na una hahine dekena ela, e hereva henia, eto, A koia, ba diba ena goada hereana na ede amo, bona edena dala amo baia hadarerea; bena baia ḡuia bona baia hamanadaia; bena silver monidia daha-ta sinahu-ta baia henimu.$h$),
    -- JDG 16:14: Samson e ḡuia
    ('cc42a375-4a52-4c12-978a-2e3578996a44'::uuid, $h$Bena Samson mahutana ai Delila ese huina e pania, ipani hitu, bena ipani hituosi na e hatuava dabuana ai e hatu kau, bona gwada-tao ḡauna amo e daia tao. Bena ia ese e hamaoroa, eto, Samson e, Filistia taudia na emu ai be kaumu. Bena ena mahuta amo e noga, gwada-tao ḡauna bona dabua ihatulaina ḡau bona e hatuava dabuana na iboudiai e raḡadia oho. Samson e ḡuia$h$,
     $h$Bena Samson mahutana ai Delila ese huina e pania, ipani hitu, bena ipani hituosi na e hatuava dabuana ai e hatu kau, bona gwada-tao ḡauna amo e daia tao. Bena ia ese e hamaoroa, eto, Samson e, Filistia taudia na emu ai be kaumu. Bena ena mahuta amo e noga, gwada-tao ḡauna bona dabua ihatulaina ḡau bona e hatuava dabuana na iboudiai e raḡadia oho.$h$),
    -- JDG 16:27: Samson e mase
    ('ab5d2d07-5a71-4029-964a-0b383b3f5a9c'::uuid, $h$Hari ruma na tatau bona hahine e honu honu dae; Filistia lohiadia iboudiai danu unuseni ai. Bona tatau bona hahine daha-toi sisivana danu atai amo e roha dobi, Samson ikirikirilaina karadia e ita. Samson e mase$h$,
     $h$Hari ruma na tatau bona hahine e honu honu dae; Filistia lohiadia iboudiai danu unuseni ai. Bona tatau bona hahine daha-toi sisivana danu atai amo e roha dobi, Samson ikirikirilaina karadia e ita.$h$),
    -- JER 4:4: Iuda bae daea
    ('c95eaffa-58ca-446f-ae74-378f335cf71b'::uuid, $h$Iuda taumui bona Ierusalem inoholaina taumui e, sibomui ba haheperitome Iehova enai, peritome ai lalomui ba hahelaḡadia, egu badu ḡaraḡara na lahi na heto baine lasi na garina, bena baine ara, asi tauna ta ese baine habodoa, emui kara vada e dika dainai. Iuda bae daea$h$,
     $h$Iuda taumui bona Ierusalem inoholaina taumui e, sibomui ba haheperitome Iehova enai, peritome ai lalomui ba hahelaḡadia, egu badu ḡaraḡara na lahi na heto baine lasi na garina, bena baine ara, asi tauna ta ese baine habodoa, emui kara vada e dika dainai.$h$),
    -- JER 8:17: Rohe-ahu Iuda bona Ierusalem latadiai
    ('3e67f2ab-c215-4510-8417-a116a78dff7e'::uuid, $h$Badina be gaigai na bogaragimui ai na siaidia vasimu, duba, basie hamanadadia diba ḡaudia; bena idia ese bae korimui. Iehova na e herevamu. Rohe-ahu Iuda bona Ierusalem latadiai$h$,
     $h$Badina be gaigai na bogaragimui ai na siaidia vasimu, duba, basie hamanadadia diba ḡaudia; bena idia ese bae korimui. Iehova na e herevamu.$h$),
    -- JER 11:17: Ieremia ihadikana e henegalaia
    ('2753dc20-425b-4321-9ddc-0a81e440b3b7'::uuid, $h$Iehova Sabaota, e hadomui Diravana, ese dika na latamui ai vada e gwauraia, badina be Israel besena bona Iuda besena vada e kara dika, bona vada e habadugu, muramura mai bonadia na Baal e gabu henia dainai. Ieremia ihadikana e henegalaia$h$,
     $h$Iehova Sabaota, e hadomui Diravana, ese dika na latamui ai vada e gwauraia, badina be Israel besena bona Iuda besena vada e kara dika, bona vada e habadugu, muramura mai bonadia na Baal e gabu henia dainai.$h$),
    -- JER 13:11: Hereva heḡereḡerena: Vine ranuna hodudia
    ('224b5626-4e2b-4478-8964-2b72accd7951'::uuid, $h$Badina be riorio ḡauna na tau ta koekoena ai e herio kunuka-kunuka na heto, lau ese Israel besena idoinai bona Iuda besena idoinai na koekoegu ai na riodia kunuka-kunuka, egu ai bese ta bona lada ta bona heimodai ta bona hairai ta ai bema lao; a idia na asie ura bae kamonai. Iehova na e herevamu. Hereva heḡereḡerena: Vine ranuna hodudia$h$,
     $h$Badina be riorio ḡauna na tau ta koekoena ai e herio kunuka-kunuka na heto, lau ese Israel besena idoinai bona Iuda besena idoinai na koekoegu ai na riodia kunuka-kunuka, egu ai bese ta bona lada ta bona heimodai ta bona hairai ta ai bema lao; a idia na asie ura bae kamonai. Iehova na e herevamu.$h$),
    -- JER 13:11: Hereva heḡereḡerena: Vine ranuna hodudia
    ('47165448-b1b7-4761-af22-e29d2dbed7d8'::uuid, $h$Badina be riorio ḡauna na tau ta koekoena ai e herio kunuka-kunuka na heto, lau ese Israel besena idoinai bona Iuda besena idoinai na koekoegu ai na riodia kunuka-kunuka, egu ai bese ta bona lada ta bona heimodai ta bona hairai ta ai bema lao; a idia na asie ura bae kamonai. Iehova na e herevamu. Hereva heḡereḡerena: Vine ranuna hodudia$h$,
     $h$Badina be riorio ḡauna na tau ta koekoena ai e herio kunuka-kunuka na heto, lau ese Israel besena idoinai bona Iuda besena idoinai na koekoegu ai na riodia kunuka-kunuka, egu ai bese ta bona lada ta bona heimodai ta bona hairai ta ai bema lao; a idia na asie ura bae kamonai. Iehova na e herevamu.$h$),
    -- JER 13:14: Iuda ena lalo-auka davana
    ('68fe5dc4-be51-4bd8-a3a6-98357c518bcf'::uuid, $h$Bena baina huaridia, ta ta, tama bona natuna, tama bona natuna, bae hehuari heheni. Basina bogadia hisi, basina hamauridia, ihabua-taridia ai basina bogalaidia. Iehova na e herevamu. Iuda ena lalo-auka davana$h$,
     $h$Bena baina huaridia, ta ta, tama bona natuna, tama bona natuna, bae hehuari heheni. Basina bogadia hisi, basina hamauridia, ihabua-taridia ai basina bogalaidia. Iehova na e herevamu.$h$),
    -- JER 34:7: Hesiai taudia iruhadia bona iḡui-loudia sivaraina
    ('83a98c71-c991-4e64-87a1-554617ae109d'::uuid, $h$Babulono pavapavana ena tuari oreana ese Ierusalem bona Iuda hanuadia oredia iboudiai, Lakisi bona Aseka, dounu e tuari henidiava negana ai. Badina be hanua mai maḡudia dounu Iuda ai e miava be unu ruaosi mo. Hesiai taudia iruhadia bona iḡui-loudia sivaraina$h$,
     $h$Babulono pavapavana ena tuari oreana ese Ierusalem bona Iuda hanuadia oredia iboudiai, Lakisi bona Aseka, dounu e tuari henidiava negana ai. Badina be hanua mai maḡudia dounu Iuda ai e miava be unu ruaosi mo.$h$),
    -- JER 34:7: Hesiai taudia iruhadia bona iḡui-loudia sivaraina
    ('d5ae38c5-3696-494b-ab64-dd649be1a553'::uuid, $h$Babulono pavapavana ena tuari oreana ese Ierusalem bona Iuda hanuadia oredia iboudiai, Lakisi bona Aseka, dounu e tuari henidiava negana ai. Badina be hanua mai maḡudia dounu Iuda ai e miava be unu ruaosi mo. Hesiai taudia iruhadia bona iḡui-loudia sivaraina$h$,
     $h$Babulono pavapavana ena tuari oreana ese Ierusalem bona Iuda hanuadia oredia iboudiai, Lakisi bona Aseka, dounu e tuari henidiava negana ai. Badina be hanua mai maḡudia dounu Iuda ai e miava be unu ruaosi mo.$h$),
    -- JHN 1:28: Ioane ese Iesu e duanaia
    ('0a7a0dd9-6454-4fb9-b30b-67030a99e4de'::uuid, $h$Ini ḡau na Betania, Ioridane unukahana ai, e vara. Ioane na unuseni ai e hahebapatisova. Ioane ese Iesu e duanaia$h$,
     $h$Ini ḡau na Betania, Ioridane unukahana ai, e vara. Ioane na unuseni ai e hahebapatisova.$h$),
    -- JHN 1:34: Ioane ena hahediba Iesu murinai e rako
    ('c7db5f70-4ea1-44ee-b1c6-cbd93a97ad36'::uuid, $h$Lau ese vada na itaia, bona vada na gwauraia hedinaraimu: ia na Dirava Natuna. Ioane ena hahediba Iesu murinai e rako$h$,
     $h$Lau ese vada na itaia, bona vada na gwauraia hedinaraimu: ia na Dirava Natuna.$h$),
    -- JHN 1:42: Filipo bona Natanael Iesu murinai e raka
    ('23c9c2b0-f14a-49fb-8d48-c00541f26f51'::uuid, $h$Bena Iesu dekena e hakaua lao. Iesu ese e raraia, bena eto, Oi na Simona, Iona natuna: Kefa na ba nemaia. (“Keta” bona “Petro” anidia tamona, “Papapapa”). Filipo bona Natanael Iesu murinai e raka$h$,
     $h$Bena Iesu dekena e hakaua lao. Iesu ese e raraia, bena eto, Oi na Simona, Iona natuna: Kefa na ba nemaia. (“Keta” bona “Petro” anidia tamona, “Papapapa”).$h$),
    -- JHN 1:42: Filipo bona Natanael Iesu murinai e raka
    ('512d0450-0058-450f-95b9-5457524ee14b'::uuid, $h$Bena Iesu dekena e hakaua lao. Iesu ese e raraia, bena eto, Oi na Simona, Iona natuna: Kefa na ba nemaia. (“Keta” bona “Petro” anidia tamona, “Papapapa”). Filipo bona Natanael Iesu murinai e raka$h$,
     $h$Bena Iesu dekena e hakaua lao. Iesu ese e raraia, bena eto, Oi na Simona, Iona natuna: Kefa na ba nemaia. (“Keta” bona “Petro” anidia tamona, “Papapapa”).$h$),
    -- JHN 1:42: Filipo bona Natanael Iesu murinai e raka
    ('5afdfdfa-2676-4e67-ae53-17c4c5fc295d'::uuid, $h$Bena Iesu dekena e hakaua lao. Iesu ese e raraia, bena eto, Oi na Simona, Iona natuna: Kefa na ba nemaia. (“Keta” bona “Petro” anidia tamona, “Papapapa”). Filipo bona Natanael Iesu murinai e raka$h$,
     $h$Bena Iesu dekena e hakaua lao. Iesu ese e raraia, bena eto, Oi na Simona, Iona natuna: Kefa na ba nemaia. (“Keta” bona “Petro” anidia tamona, “Papapapa”).$h$),
    -- JHN 2:12: Ierusalem ai: Laḡau-hanai
    ('5c914676-ef73-4ab2-b68c-7aa63a1a57a5'::uuid, $h$Una murinai ia mai sinala ida, bona tadina bona ena hahediba ida, e diho ela Kaperanaum ai, unuseni ai dina dia hoho e nohova. Ierusalem ai: Laḡau-hanai$h$,
     $h$Una murinai ia mai sinala ida, bona tadina bona ena hahediba ida, e diho ela Kaperanaum ai, unuseni ai dina dia hoho e nohova.$h$),
    -- JHN 2:12: Ierusalem ai: Laḡau-hanai
    ('c7a9815e-9430-474e-a249-18090f5c99db'::uuid, $h$Una murinai ia mai sinala ida, bona tadina bona ena hahediba ida, e diho ela Kaperanaum ai, unuseni ai dina dia hoho e nohova. Ierusalem ai: Laḡau-hanai$h$,
     $h$Una murinai ia mai sinala ida, bona tadina bona ena hahediba ida, e diho ela Kaperanaum ai, unuseni ai dina dia hoho e nohova.$h$),
    -- JHN 4:42: Galilea ai
    ('3fd4ee50-21b1-4e0f-8fcc-c026e0c14c02'::uuid, $h$Bena idia ese una hahine e hamaoroa, eto, Ai na dia harihari oiemu hereva dainai asia abiabiraiamu, a badina be ai sibomai vada ame kamonai bona ame diba ina na momokani tanobada ihamauruina tauna. Galilea ai$h$,
     $h$Bena idia ese una hahine e hamaoroa, eto, Ai na dia harihari oiemu hereva dainai asia abiabiraiamu, a badina be ai sibomai vada ame kamonai bona ame diba ina na momokani tanobada ihamauruina tauna.$h$),
    -- JHN 4:42: Galilea ai
    ('4d5989d1-36a5-42a7-97e3-9fd6d18c7911'::uuid, $h$Bena idia ese una hahine e hamaoroa, eto, Ai na dia harihari oiemu hereva dainai asia abiabiraiamu, a badina be ai sibomai vada ame kamonai bona ame diba ina na momokani tanobada ihamauruina tauna. Galilea ai$h$,
     $h$Bena idia ese una hahine e hamaoroa, eto, Ai na dia harihari oiemu hereva dainai asia abiabiraiamu, a badina be ai sibomai vada ame kamonai bona ame diba ina na momokani tanobada ihamauruina tauna.$h$),
    -- JHN 6:66: Ḡwauta-raruosi Iesu enai e tao
    ('f38fc5ea-ade2-41d7-a767-70cb0b1a2892'::uuid, $h$Una negana ai ena hahediba hutuma ese e rakatania, bona ia ida asie raka hebou lou. Ḡwauta-raruosi Iesu enai e tao$h$,
     $h$Una negana ai ena hahediba hutuma ese e rakatania, bona ia ida asie raka hebou lou.$h$),
    -- JHN 12:11: Iesu na Ierusalem ai e dara dae
    ('b081a9c0-9fbf-497e-af46-cb1117883668'::uuid, $h$badina be ia dainai Iuda taudia hutuma na e raka ohova, Iesu e abiabiraiava. Iesu na Ierusalem ai e dara dae$h$,
     $h$badina be ia dainai Iuda taudia hutuma na e raka ohova, Iesu e abiabiraiava.$h$),
    -- JHN 18:18: Iesu e hahemaoro henia
    ('3fdfce02-de06-491f-94c7-5bb7672226da'::uuid, $h$Ḡaukara taudia bona hesiai taudia na e kerudia dainai lahi e haraia, badinai e gini, e heganava. Petro danu idia ida e gini hebou, e heganava. Iesu e hahemaoro henia$h$,
     $h$Ḡaukara taudia bona hesiai taudia na e kerudia dainai lahi e haraia, badinai e gini, e heganava. Petro danu idia ida e gini hebou, e heganava.$h$),
    -- JHN 18:24: Petro ma e hegore
    ('161c9c9f-2d33-4ff2-95f2-8945a1827e98'::uuid, $h$Bena Ana ese mai iḡuina ida e siaia lao, Kaiata, hahelaḡa tauna badana, dekena. Petro ma e hegore$h$,
     $h$Bena Ana ese mai iḡuina ida e siaia lao, Kaiata, hahelaḡa tauna badana, dekena.$h$),
    -- JHN 18:24: Petro ma e hegore
    ('2acace61-a933-4c98-801f-ccbc3ed35846'::uuid, $h$Bena Ana ese mai iḡuina ida e siaia lao, Kaiata, hahelaḡa tauna badana, dekena. Petro ma e hegore$h$,
     $h$Bena Ana ese mai iḡuina ida e siaia lao, Kaiata, hahelaḡa tauna badana, dekena.$h$),
    -- JHN 18:27: Iesu Pilatv vairanai
    ('191d752b-1206-4c84-a160-4d44460a52d0'::uuid, $h$Petro ma e heḡore lou. Bena kokoroku vada e tai. Iesu Pilatv vairanai$h$,
     $h$Petro ma e heḡore lou. Bena kokoroku vada e tai.$h$),
    -- JHN 21:23: Evanelia tauna ena hereva dokona
    ('8464ba9f-2d54-4745-91d1-fcab1f4760a7'::uuid, $h$Ina hereva na Iesu ena orea taudia bogaragidiai e piua, una hahediba na basine mase eto. A Iesu na seto “Ia na basine mase”; to eto “Baina ura ia na baine noho ela bona lau baina lou mai, una be dahaka oiemu ai?” Evanelia tauna ena hereva dokona$h$,
     $h$Ina hereva na Iesu ena orea taudia bogaragidiai e piua, una hahediba na basine mase eto. A Iesu na seto “Ia na basine mase”; to eto “Baina ura ia na baine noho ela bona lau baina lou mai, una be dahaka oiemu ai?”$h$),
    -- JOB 42:6: Iobu ena noho-namo ma e vara lou
    ('5b859545-2ff7-4f1a-b34c-1efa711ed7a0'::uuid, $h$una dainai lau na sibogu na hedadaraimu, ḡahu bona kahu ai na helalo kerehaimu. Iobu ena noho-namo ma e vara lou$h$,
     $h$una dainai lau na sibogu na hedadaraimu, ḡahu bona kahu ai na helalo kerehaimu.$h$),
    -- JOS 10:27: Hanua momo e habuadia tari
    ('56c0668b-c8cb-45db-86a7-a5075a69139a'::uuid, $h$Dina e diho, bena Iosua e hahedua, bena haida ese au amo e abidia dobi, Ialonai e komuva kohuana ai ma e tahodia vareai; bena nadi badadia e abi, kohua iduarana e kurea ahu. Unu e mia tomamu ema bona han dina. Hanua momo e habuadia tari$h$,
     $h$Dina e diho, bena Iosua e hahedua, bena haida ese au amo e abidia dobi, Ialonai e komuva kohuana ai ma e tahodia vareai; bena nadi badadia e abi, kohua iduarana e kurea ahu. Unu e mia tomamu ema bona han dina.$h$),
    -- JOS 10:27: Hanua momo e habuadia tari
    ('dd5db881-88ad-494c-a4a8-3c8b82676385'::uuid, $h$Dina e diho, bena Iosua e hahedua, bena haida ese au amo e abidia dobi, Ialonai e komuva kohuana ai ma e tahodia vareai; bena nadi badadia e abi, kohua iduarana e kurea ahu. Unu e mia tomamu ema bona han dina. Hanua momo e habuadia tari$h$,
     $h$Dina e diho, bena Iosua e hahedua, bena haida ese au amo e abidia dobi, Ialonai e komuva kohuana ai ma e tahodia vareai; bena nadi badadia e abi, kohua iduarana e kurea ahu. Unu e mia tomamu ema bona han dina.$h$),
    -- JOS 19:16: Isakara ahuna
    ('61e1b1ca-4fa4-459f-b779-859a88d7ae97'::uuid, $h$Sebulun taudia ahudia bunu, edia dogoro ta ta ai: unu hanua e abi, mai edia hanua maraḡidia ida. Isakara ahuna$h$,
     $h$Sebulun taudia ahudia bunu, edia dogoro ta ta ai: unu hanua e abi, mai edia hanua maraḡidia ida.$h$),
    -- JOS 24:32: Eleasara e mase
    ('e32e11ba-45c5-4921-95e2-2e67c4ce50cd'::uuid, $h$Iosef turiana, Israel taudia ese Aigupto amo e mailaidia, na Sekem ai e guridia, Iakob ese Sekem tamana Hamoro ena amo e hoia tanona ai. Davana be silver monidia sinahu-ta e heni; bena Iosef garana edia tano ai ela. Eleasara e mase$h$,
     $h$Iosef turiana, Israel taudia ese Aigupto amo e mailaidia, na Sekem ai e guridia, Iakob ese Sekem tamana Hamoro ena amo e hoia tanona ai. Davana be silver monidia sinahu-ta e heni; bena Iosef garana edia tano ai ela.$h$),
    -- LEV 7:21: Digara bona Rara
    ('d8f7cb31-1093-4847-99c0-65f02abb9961'::uuid, $h$bona tau ta ese taunimanima edia ḡau mirona ta, eiava mauri ḡaudia mirodia ta, eiava ḡau mirona eiava bodagana ta, bema daua toho, murinai Iehova ena herohemaino bouboudia hidiodia bema ani, ia na ena bese amo bae negea daure. Digara bona Rara$h$,
     $h$bona tau ta ese taunimanima edia ḡau mirona ta, eiava mauri ḡaudia mirodia ta, eiava ḡau mirona eiava bodagana ta, bema daua toho, murinai Iehova ena herohemaino bouboudia hidiodia bema ani, ia na ena bese amo bae negea daure.$h$),
    -- LEV 7:21: Digara bona Rara
    ('eca8b32c-f318-4c7e-b78a-9de870b08488'::uuid, $h$bona tau ta ese taunimanima edia ḡau mirona ta, eiava mauri ḡaudia mirodia ta, eiava ḡau mirona eiava bodagana ta, bema daua toho, murinai Iehova ena herohemaino bouboudia hidiodia bema ani, ia na ena bese amo bae negea daure. Digara bona Rara$h$,
     $h$bona tau ta ese taunimanima edia ḡau mirona ta, eiava mauri ḡaudia mirodia ta, eiava ḡau mirona eiava bodagana ta, bema daua toho, murinai Iehova ena herohemaino bouboudia hidiodia bema ani, ia na ena bese amo bae negea daure.$h$),
    -- LEV 22:16: Boubou Ḡaudia Taravatudia
    ('b95d8505-c2cb-4d60-b996-f0957a2204a0'::uuid, $h$aniani helaḡadia bae ani kava na e mailaidia taudia bae hakereredia; badina be lau Iehova ese vada na hahelaḡadia. Boubou Ḡaudia Taravatudia$h$,
     $h$aniani helaḡadia bae ani kava na e mailaidia taudia bae hakereredia; badina be lau Iehova ese vada na hahelaḡadia.$h$),
    -- LEV 24:9: Dirava iuduguiraina, davana
    ('fd9b3266-87b9-48a4-b343-942f69381362'::uuid, $h$Una flaoa na Aaron mai natuna ida adia; gabu helaḡana ai bae ania, Iehova ena Iahi bouboudia iboudiai ia mo sibona helaḡa herea. Mia-hanaihanai taravatuna bunai. Dirava iuduguiraina, davana$h$,
     $h$Una flaoa na Aaron mai natuna ida adia; gabu helaḡana ai bae ania, Iehova ena Iahi bouboudia iboudiai ia mo sibona helaḡa herea. Mia-hanaihanai taravatuna bunai.$h$),
    -- LEV 26:13: Gwau-edeede ahuna
    ('3f76238e-7601-45e9-a1b6-6dc52dcad897'::uuid, $h$Lau binai Iehova, emui Dirava: Aigupto tanona amo na hakaumui lasi, Aigupto taudia isiaidia basio lao heni nato; aiomui gadeadia na hamotudia, na haginimui maoromaoro. Gwau-edeede ahuna$h$,
     $h$Lau binai Iehova, emui Dirava: Aigupto tanona amo na hakaumui lasi, Aigupto taudia isiaidia basio lao heni nato; aiomui gadeadia na hamotudia, na haginimui maoromaoro.$h$),
    -- LEV 26:13: Gwau-edeede ahuna
    ('79708942-9cad-4c84-9930-afce2c78fcb2'::uuid, $h$Lau binai Iehova, emui Dirava: Aigupto tanona amo na hakaumui lasi, Aigupto taudia isiaidia basio lao heni nato; aiomui gadeadia na hamotudia, na haginimui maoromaoro. Gwau-edeede ahuna$h$,
     $h$Lau binai Iehova, emui Dirava: Aigupto tanona amo na hakaumui lasi, Aigupto taudia isiaidia basio lao heni nato; aiomui gadeadia na hamotudia, na haginimui maoromaoro.$h$),
    -- LEV 26:13: Gwau-edeede ahuna
    ('952a2fb4-ed8e-468e-b99e-14cf8398c580'::uuid, $h$Lau binai Iehova, emui Dirava: Aigupto tanona amo na hakaumui lasi, Aigupto taudia isiaidia basio lao heni nato; aiomui gadeadia na hamotudia, na haginimui maoromaoro. Gwau-edeede ahuna$h$,
     $h$Lau binai Iehova, emui Dirava: Aigupto tanona amo na hakaumui lasi, Aigupto taudia isiaidia basio lao heni nato; aiomui gadeadia na hamotudia, na haginimui maoromaoro.$h$),
    -- LEV 26:13: Gwau-edeede ahuna
    ('a34f3142-4164-42c6-88e3-f48dadab64e1'::uuid, $h$Lau binai Iehova, emui Dirava: Aigupto tanona amo na hakaumui lasi, Aigupto taudia isiaidia basio lao heni nato; aiomui gadeadia na hamotudia, na haginimui maoromaoro. Gwau-edeede ahuna$h$,
     $h$Lau binai Iehova, emui Dirava: Aigupto tanona amo na hakaumui lasi, Aigupto taudia isiaidia basio lao heni nato; aiomui gadeadia na hamotudia, na haginimui maoromaoro.$h$),
    -- LEV 26:13: Gwau-edeede ahuna
    ('c8777bd1-5279-4d33-bc98-47b4aa46988d'::uuid, $h$Lau binai Iehova, emui Dirava: Aigupto tanona amo na hakaumui lasi, Aigupto taudia isiaidia basio lao heni nato; aiomui gadeadia na hamotudia, na haginimui maoromaoro. Gwau-edeede ahuna$h$,
     $h$Lau binai Iehova, emui Dirava: Aigupto tanona amo na hakaumui lasi, Aigupto taudia isiaidia basio lao heni nato; aiomui gadeadia na hamotudia, na haginimui maoromaoro.$h$),
    -- LUK 1:4: Sakaria bona Elisabeta
    ('28912a3a-d552-45bc-9725-1d855176256c'::uuid, $h$Vada ba diba, e hadibamuiva herevadia be momomo-kakani. Sakaria bona Elisabeta$h$,
     $h$Vada ba diba, e hadibamuiva herevadia be momomo-kakani.$h$),
    -- LUK 1:4: Sakaria bona Elisabeta
    ('645a8c62-4b9f-44a1-85d1-9f5ef01b85e1'::uuid, $h$Vada ba diba, e hadibamuiva herevadia be momomo-kakani. Sakaria bona Elisabeta$h$,
     $h$Vada ba diba, e hadibamuiva herevadia be momomo-kakani.$h$),
    -- LUK 1:4: Sakaria bona Elisabeta
    ('aca4b0dc-d321-4519-99c9-51d5c1b061d7'::uuid, $h$Vada ba diba, e hadibamuiva herevadia be momomo-kakani. Sakaria bona Elisabeta$h$,
     $h$Vada ba diba, e hadibamuiva herevadia be momomo-kakani.$h$),
    -- LUK 2:21: Iesu Ierusalem e laohaia
    ('5805b39b-951d-4489-8cad-bb14d17ba45f'::uuid, $h$Dina ihataurahanina ai, mero iperitomena negana ai, idia ese ladana e hatoa IESU, sinana do se rurua negana ai aneru ese e hatoa ladana. Iesu Ierusalem e laohaia$h$,
     $h$Dina ihataurahanina ai, mero iperitomena negana ai, idia ese ladana e hatoa IESU, sinana do se rurua negana ai aneru ese e hatoa ladana.$h$),
    -- LUK 2:40: Mero Iesu na Ierusalem ela
    ('04ac67d2-dee3-4944-8dae-85c0755bd84c'::uuid, $h$Bena mero na e bada, mai goadana bona mai aonegana ida, bona Dirava ena hariharibada na ia latanai. Mero Iesu na Ierusalem ela$h$,
     $h$Bena mero na e bada, mai goadana bona mai aonegana ida, bona Dirava ena hariharibada na ia latanai.$h$),
    -- LUK 4:39: Gorere taudiu hutuma e hamauridia
    ('4ee41bcd-9e31-4445-b182-33f29ffd2f3e'::uuid, $h$Ia na hahine dekenai e gini, gorere e gwau henia, bena gorere e doko, hahine na e tore isi, idia isiaidia e lao heni. Gorere taudiu hutuma e hamauridia$h$,
     $h$Ia na hahine dekenai e gini, gorere e gwau henia, bena gorere e doko, hahine na e tore isi, idia isiaidia e lao heni.$h$),
    -- LUK 5:11: Iesu ese lepra tauna e hamauria
    ('9addd1a1-67ac-4d92-aefe-af0097afb592'::uuid, $h$Vanaḡi auruaosi na kone badinai e tudia, bena ḡau iboudiai e rakatani, ia murinai e raka. Iesu ese lepra tauna e hamauria$h$,
     $h$Vanaḡi auruaosi na kone badinai e tudia, bena ḡau iboudiai e rakatani, ia murinai e raka.$h$),
    -- LUK 6:5: Taravatu ma e tata utu
    ('32a825c8-b58c-40be-bfc6-652b0fff7433'::uuid, $h$Ma e hamaoro-lia, eto, Taunimanima Natuna na Dina Helaḡa biaguna. Taravatu ma e tata utu$h$,
     $h$Ma e hamaoro-lia, eto, Taunimanima Natuna na Dina Helaḡa biaguna.$h$),
    -- LUK 6:19: Daidia nanamo?
    ('88f168c0-8ab5-41f5-a6e4-3a951255d75f'::uuid, $h$Bena aru taudia iboudiai idau-tohona urana e urava, badina be siahu na iena amo e lasi, iboudiai e hamauridia. Daidia nanamo?$h$,
     $h$Bena aru taudia iboudiai idau-tohona urana e urava, badina be siahu na iena amo e lasi, iboudiai e hamauridia.$h$),
    -- LUK 6:26: Lalokau korikori
    ('7540f3f4-ec85-499b-89a3-77c4344e1697'::uuid, $h$Taunimanima iboudiai bae hanamomui negadia ai, madi habaimui; badina be senedia ese peroveta taudia koikoidia unu e hanamodia toma. Lalokau korikori$h$,
     $h$Taunimanima iboudiai bae hanamomui negadia ai, madi habaimui; badina be senedia ese peroveta taudia koikoidia unu e hanamodia toma.$h$),
    -- LUK 8:3: Sivarai heḡereḡerena: uit iḡiḡi-rohorohona
    ('3106b550-5126-436d-9322-c56e5170d3f2'::uuid, $h$Ma ta be Ioana, Kusa, Herod ena kohu ireḡuna tauna, adavana. Ta danu Susana. Ma hutuma danu, edia ḡau ia e ubulaia. Sivarai heḡereḡerena: uit iḡiḡi-rohorohona$h$,
     $h$Ma ta be Ioana, Kusa, Herod ena kohu ireḡuna tauna, adavana. Ta danu Susana. Ma hutuma danu, edia ḡau ia e ubulaia.$h$),
    -- LUK 8:3: Sivarai heḡereḡerena: uit iḡiḡi-rohorohona
    ('8bd2f6fc-f3d2-43cb-ae7a-c6a42ed41baa'::uuid, $h$Ma ta be Ioana, Kusa, Herod ena kohu ireḡuna tauna, adavana. Ta danu Susana. Ma hutuma danu, edia ḡau ia e ubulaia. Sivarai heḡereḡerena: uit iḡiḡi-rohorohona$h$,
     $h$Ma ta be Ioana, Kusa, Herod ena kohu ireḡuna tauna, adavana. Ta danu Susana. Ma hutuma danu, edia ḡau ia e ubulaia.$h$),
    -- LUK 8:3: Sivarai heḡereḡerena: uit iḡiḡi-rohorohona
    ('8d9334e5-8893-40ad-869f-7719118142b6'::uuid, $h$Ma ta be Ioana, Kusa, Herod ena kohu ireḡuna tauna, adavana. Ta danu Susana. Ma hutuma danu, edia ḡau ia e ubulaia. Sivarai heḡereḡerena: uit iḡiḡi-rohorohona$h$,
     $h$Ma ta be Ioana, Kusa, Herod ena kohu ireḡuna tauna, adavana. Ta danu Susana. Ma hutuma danu, edia ḡau ia e ubulaia.$h$),
    -- LUK 9:45: Manau herevadia
    ('13424f33-c942-4bc6-8a72-d34d643348c8'::uuid, $h$A una hereva na lalodia asie parara, edia amo e hehunii, anina asie davaria; bona ioa inanadailaina garina e gari. Manau herevadia$h$,
     $h$A una hereva na lalodia asie parara, edia amo e hehunii, anina asie davaria; bona ioa inanadailaina garina e gari.$h$),
    -- LUK 10:16: Hitu-ahui-osi e lou
    ('4700cc93-3b71-4b10-abad-f9501940628e'::uuid, $h$Umui e kamonai henimuimu tauna ese lau e kamonai henigumu; bona umui e dadaraimuimu tauna ese lau e dadaraigumu; bona lau e dadaraigumu tauna ese lau e siaigu Diravana danu e dadaraiamu. Hitu-ahui-osi e lou$h$,
     $h$Umui e kamonai henimuimu tauna ese lau e kamonai henigumu; bona umui e dadaraimuimu tauna ese lau e dadaraigumu; bona lau e dadaraigumu tauna ese lau e siaigu Diravana danu e dadaraiamu.$h$),
    -- LUK 10:37: Mareta bona Maria
    ('8ea0a7fe-2bf3-47f8-829e-090d2a85c80e'::uuid, $h$Ia eto, E bogaia hisi tauna. Bena Iesu eto, Aola, oi danu unu ma ba ha kara toma. Mareta bona Maria$h$,
     $h$Ia eto, E bogaia hisi tauna. Bena Iesu eto, Aola, oi danu unu ma ba ha kara toma.$h$),
    -- LUK 11:36: Iesu ese Farisea taudia bona taravatu taudia e gwau henidia
    ('709de408-53cb-4cc3-a1cb-91bc1fa8d133'::uuid, $h$Badina be taumu idoinai baine diari, dibura sina taina basine mia, ia na baine diari ḡuḡuru, lamepa e hururu-hururumu, oi e hadiarilaimumu, heḡereḡerena. Iesu ese Farisea taudia bona taravatu taudia e gwau henidia$h$,
     $h$Badina be taumu idoinai baine diari, dibura sina taina basine mia, ia na baine diari ḡuḡuru, lamepa e hururu-hururumu, oi e hadiarilaimumu, heḡereḡerena.$h$),
    -- LUK 13:9: Iesu ese Dina Helaḡa ai e hahemouri
    ('959eb376-7fc5-42d4-aa27-9f1a94c49f61'::uuid, $h$bena huahuana baine dobi be baine namo, a bema lasi boma utua. Iesu ese Dina Helaḡa ai e hahemouri$h$,
     $h$bena huahuana baine dobi be baine namo, a bema lasi boma utua.$h$),
    -- LUK 13:17: Sivarai heḡereḡerena: Sinapi nadinodina
    ('5fab53c7-73c8-4b82-af6a-259714a5b98d'::uuid, $h$Unu e gwau toma, bena e inai heniava taudia vada e hemarai. A aru taudia ese ena kara herea-daedia e moalelai. Sivarai heḡereḡerena: Sinapi nadinodina$h$,
     $h$Unu e gwau toma, bena e inai heniava taudia vada e hemarai. A aru taudia ese ena kara herea-daedia e moalelai.$h$),
    -- LUK 13:21: Dirava ena basileia iraka-vareaina
    ('7f317cd1-126d-444e-ae54-06cdcf3e9012'::uuid, $h$Ia na halubu muramurana na heto, hahine ta ese e abia, flaoa nau autoi ida e buloa, ela bona idoinai vada e tubu. Dirava ena basileia iraka-vareaina$h$,
     $h$Ia na halubu muramurana na heto, hahine ta ese e abia, flaoa nau autoi ida e buloa, ela bona idoinai vada e tubu.$h$),
    -- LUK 14:14: Sivarai heḡereḡerena: Anibou badana
    ('47271cd7-f0ed-4d71-a829-458392aaebaf'::uuid, $h$unu amo vada ba namo, badina be idia na asi edia kohu bena basie hadavaia, bena kara maoromaoro tore-isina ai davamu bavabia. Sivarai heḡereḡerena: Anibou badana$h$,
     $h$unu amo vada ba namo, badina be idia na asi edia kohu bena basie hadavaia, bena kara maoromaoro tore-isina ai davamu bavabia.$h$),
    -- LUK 15:7: Sivarai heḡereḡerena. Moni e boio
    ('b9d64078-b876-4d9f-b1a8-11688796bf84'::uuid, $h$Na hamaoromuimu, dika tauna ta e helalo kerehaimu dainai guba ai moale baine bada; a kara maoromaoro taudia taurahani-ta-ahui laurahani-ta asie helalo kerehaimu daidiai guba ai moale baine maraḡi. Sivarai heḡereḡerena. Moni e boio$h$,
     $h$Na hamaoromuimu, dika tauna ta e helalo kerehaimu dainai guba ai moale baine bada; a kara maoromaoro taudia taurahani-ta-ahui laurahani-ta asie helalo kerehaimu daidiai guba ai moale baine maraḡi.$h$),
    -- LUK 15:10: Sivarai heḡereḡerena: Mero e raka boioboio
    ('2104176c-8ea3-40d2-aca4-07df95a34791'::uuid, $h$Na hamaoromuimu, dika tauna ta e helalo kerehaimu dainai Dirava ena aneru unu bae moak toma. Sivarai heḡereḡerena: Mero e raka boioboio$h$,
     $h$Na hamaoromuimu, dika tauna ta e helalo kerehaimu dainai Dirava ena aneru unu bae moak toma.$h$),
    -- LUK 19:44: Hoihoi taudia na Dubu Helaḡa amo e luludia lasi
    ('dd3ae9c8-8e78-4c96-818a-b84de0db9625'::uuid, $h$Bena tano ai bae kohumu tao, natumu danu bae kohudia tao, bona nadi ta nadi ta latanai basine mia; badina be ivadivadi-henimu negana na asi dibamui. Hoihoi taudia na Dubu Helaḡa amo e luludia lasi$h$,
     $h$Bena tano ai bae kohumu tao, natumu danu bae kohudia tao, bona nadi ta nadi ta latanai basine mia; badina be ivadivadi-henimu negana na asi dibamui.$h$),
    -- LUK 20:8: Sivarai heḡereḡerena: Imea iteḡudia taudia dikadia
    ('2950573f-a800-4541-af78-5babf5b2e04d'::uuid, $h$Bena Iesu eto, Lau danu ini ḡau na karalaimu siahuna na basina hamaorolaimui. Sivarai heḡereḡerena: Imea iteḡudia taudia dikadia$h$,
     $h$Bena Iesu eto, Lau danu ini ḡau na karalaimu siahuna na basina hamaorolaimui.$h$),
    -- LUK 24:12: Iesu na Emausa dalana ai e hedinarai
    ('1ccfa584-69de-4478-9ff1-23c195f38685'::uuid, $h$A Petro e tore isi, e heau lao, gara lalonai eha igoa, dabua mo e ita; bena ena ruma e lou henia, e vara ḡaudia e hoalai. Iesu na Emausa dalana ai e hedinarai$h$,
     $h$A Petro e tore isi, e heau lao, gara lalonai eha igoa, dabua mo e ita; bena ena ruma e lou henia, e vara ḡaudia e hoalai.$h$),
    -- LUK 24:35: Iesu bogaragidiai ma e hedinarai
    ('3ee66e5c-3f4a-4b0e-8a5b-3fa3b2fd35fe'::uuid, $h$Bena raruosi ese dala ai e vara ḡaudia na e hamaorolaidia, bona flaoa atagana ibituna ai lalodia e parara herevana danu. Iesu bogaragidiai ma e hedinarai$h$,
     $h$Bena raruosi ese dala ai e vara ḡaudia na e hamaorolaidia, bona flaoa atagana ibituna ai lalodia e parara herevana danu.$h$),
    -- LUK 24:49: Iesu guha ai e heabi dae
    ('61976631-38cf-443f-a256-cb103f32b2c0'::uuid, $h$A lau ese Tamagu e gwauraia hamata ḡauna baina siaia, latamui ai baine kau; taunabunai, umui na Ierusalem ai ba noho ela bona atai amo baine diho siahuna na do bavabia. Iesu guha ai e heabi dae$h$,
     $h$A lau ese Tamagu e gwauraia hamata ḡauna baina siaia, latamui ai baine kau; taunabunai, umui na Ierusalem ai ba noho ela bona atai amo baine diho siahuna na do bavabia.$h$),
    -- MAL 2:9: Iehova ese Israel e gwau henia
    ('1dce4eac-bd60-4d80-a8ab-267ba20828ad'::uuid, $h$Taunabunai, lau ese baina hahemaraimui bona baina ha-igomui diho, taunimanima iboudiai vairadiai, egu dala asio badinadia bona emui hahediba ai kaha ta enai o tao dainai. Iehova ese Israel e gwau henia$h$,
     $h$Taunabunai, lau ese baina hahemaraimui bona baina ha-igomui diho, taunimanima iboudiai vairadiai, egu dala asio badinadia bona emui hahediba ai kaha ta enai o tao dainai.$h$),
    -- MAT 2:18: Nasaret e lou henia
    ('6ed7f240-41d2-4992-9680-b4b9d0dfbc31'::uuid, $h$Gado ta Rama ai e kamonai, Tai lolololo bona tai ḡadeḡade bada, Rahela be natuna taidia e taimu, Tauhalo e dadaraia, badina be idia na lasihidia. Nasaret e lou henia$h$,
     $h$Gado ta Rama ai e kamonai, Tai lolololo bona tai ḡadeḡade bada, Rahela be natuna taidia e taimu, Tauhalo e dadaraia, badina be idia na lasihidia.$h$),
    -- MAT 3:12: Iesu e bapatisoa
    ('02daf36a-a425-431c-8844-558a7e826795'::uuid, $h$Ena itapo na imana ai; ena uit ikwadina gabuna baine tapoa ḡoevaḡoeva, ena uit na roge ai baine haboua, a momona be se bodomu lahina ai baine dou vaitani. Iesu e bapatisoa$h$,
     $h$Ena itapo na imana ai; ena uit ikwadina gabuna baine tapoa ḡoevaḡoeva, ena uit na roge ai baine haboua, a momona be se bodomu lahina ai baine dou vaitani.$h$),
    -- MAT 7:12: Dala korikorina
    ('2b622da8-12c2-4719-a742-0399f2ac7c23'::uuid, $h$Taunabunai, ḡau iboudiai umui ba ura taunimanima ese bae kara henimui, umui ese unu ba kara henidia toma; badina be ta avatu bona peroveta herevadia anidia korikori bunai. Dala korikorina$h$,
     $h$Taunabunai, ḡau iboudiai umui ba ura taunimanima ese bae kara henimui, umui ese unu ba kara henidia toma; badina be ta avatu bona peroveta herevadia anidia korikori bunai.$h$),
    -- MAT 9:17: Heabidadama toadia
    ('2b3f8240-c2b3-4fdc-96a6-5db6ccbd3248'::uuid, $h$Vine ranuna matamatana kopi gunadia ai basie vedaia. Unu bema kara toma, vine ranuna matamatana ese kopi bema hapou, bena vine ranuna bona kopi bema dika bou. A vine ranuna matamata na kopi matamatadia ai bae vedaia, bena ruaosi bae namo. Heabidadama toadia$h$,
     $h$Vine ranuna matamatana kopi gunadia ai basie vedaia. Unu bema kara toma, vine ranuna matamatana ese kopi bema hapou, bena vine ranuna bona kopi bema dika bou. A vine ranuna matamata na kopi matamatadia ai bae vedaia, bena ruaosi bae namo.$h$),
    -- MAT 10:4: Aposetolo edia ḡaukara e henidia
    ('6e223137-1a73-473b-ad39-ff7aeb620b46'::uuid, $h$Simona, Selote tauna bona Iuda Iskariote, ia na Iesu taona itorena tauna. Aposetolo edia ḡaukara e henidia$h$,
     $h$Simona, Selote tauna bona Iuda Iskariote, ia na Iesu taona itorena tauna.$h$),
    -- MAT 10:4: Aposetolo edia ḡaukara e henidia
    ('fb4aaec9-7a25-4a07-82af-b1a085e74115'::uuid, $h$Simona, Selote tauna bona Iuda Iskariote, ia na Iesu taona itorena tauna. Aposetolo edia ḡaukara e henidia$h$,
     $h$Simona, Selote tauna bona Iuda Iskariote, ia na Iesu taona itorena tauna.$h$),
    -- MAT 11:19: Iesu ese Galilea hanuadia e gwau henidia
    ('bfb799b6-e17d-4b68-9481-3c3d5fc61ffb'::uuid, $h$A Taunimanima Natuna vada ema, e anianimu, e inuinumu, bena idia e tomu “Ina na ani-dae ani-dae bona vine ranuna e inua momomu tauna, tax gogo taudia bona kara dika taudia turadia”. A aonega ihamomokanina na natuna edia amo e hedinaraimu. Iesu ese Galilea hanuadia e gwau henidia$h$,
     $h$A Taunimanima Natuna vada ema, e anianimu, e inuinumu, bena idia e tomu “Ina na ani-dae ani-dae bona vine ranuna e inua momomu tauna, tax gogo taudia bona kara dika taudia turadia”. A aonega ihamomokanina na natuna edia amo e hedinaraimu.$h$),
    -- MAT 13:30: Sivarai heḡereḡerena: sinapi nadinadina
    ('1d9cbbfc-371b-41b0-99f8-e73650b85eed'::uuid, $h$Do bae mia, bae vara hebou, ela bona uit iutuna negana. Bena lau ese iutuna taudia baina hamaorodia, bainato, Ava dikadia ba habou guna, ba ḡui, lahi ḡauna, a uit na egu roge ai ba habou. Sivarai heḡereḡerena: sinapi nadinadina$h$,
     $h$Do bae mia, bae vara hebou, ela bona uit iutuna negana. Bena lau ese iutuna taudia baina hamaorodia, bainato, Ava dikadia ba habou guna, ba ḡui, lahi ḡauna, a uit na egu roge ai ba habou.$h$),
    -- MAT 13:32: Sivarai heḡereḡerena: flaoa ihatubuna muramurana
    ('8ded02ae-c07b-4be9-8476-1bb526123ad3'::uuid, $h$Au nadinadidia loḡora iboudiai ia mo sibona maraḡi-maraḡi herea; a e tubumu negana ai, aniani avadia iboudiai e tubutanimu, au ai e laomu, bena atai manudia na ia rigina ai e roho kaumu, laḡadia e animu. Sivarai heḡereḡerena: flaoa ihatubuna muramurana$h$,
     $h$Au nadinadidia loḡora iboudiai ia mo sibona maraḡi-maraḡi herea; a e tubumu negana ai, aniani avadia iboudiai e tubutanimu, au ai e laomu, bena atai manudia na ia rigina ai e roho kaumu, laḡadia e animu.$h$),
    -- MAT 13:52: Nasaret taudia ese Iesu e dadaraia
    ('11d5bf4f-b953-49a9-addb-0136b1d5081d'::uuid, $h$Bena ia ese e hamaorodia, eto, Benaini, itorena tauna ta ese guba basileiana hahedibana ai bainela, ia na ruma biaguna ta na heto, kohu matamatadia bona gunadia ena taḡa amo e vaimu. Nasaret taudia ese Iesu e dadaraia$h$,
     $h$Bena ia ese e hamaorodia, eto, Benaini, itorena tauna ta ese guba basileiana hahedibana ai bainela, ia na ruma biaguna ta na heto, kohu matamatadia bona gunadia ena taḡa amo e vaimu.$h$),
    -- MAT 14:33: Iesu Genesaret ai
    ('29cd8fc7-2e02-46a3-809d-030c1b1e70a9'::uuid, $h$Vanaḡi taudia na ia vairanai e toma diho, eto, Momokani, oi na Dirava Natuna. Iesu Genesaret ai$h$,
     $h$Vanaḡi taudia na ia vairanai e toma diho, eto, Momokani, oi na Dirava Natuna.$h$),
    -- MAT 15:31: Iesu ese taunimanima 4000 e ubudia
    ('1b7aa5cc-7353-4333-8eab-8c563b2ad710'::uuid, $h$Taunabunai, aru taudia na e hoa, badina be e itadia: mu taudia e herevava, ima-doko taudia e goadava, ae-hedairike taudia e rakava, mata-kepulu taudia e roharohava. Bena Israel edia Dirava vada e heatolaia. Iesu ese taunimanima 4000 e ubudia$h$,
     $h$Taunabunai, aru taudia na e hoa, badina be e itadia: mu taudia e herevava, ima-doko taudia e goadava, ae-hedairike taudia e rakava, mata-kepulu taudia e roharohava. Bena Israel edia Dirava vada e heatolaia.$h$),
    -- MAT 16:4: Hahediba e daradara
    ('5f8f0ce2-7459-46de-be61-6ccd8d34f814'::uuid, $h$Uru dikana mai heudahanaina ese toa e tahuamu, a toa ta basie abia, Iona peroveta tauna toana mo vadaeni. Bena ia ese a rakatanidia, e raka oho. Hahediba e daradara$h$,
     $h$Uru dikana mai heudahanaina ese toa e tahuamu, a toa ta basie abia, Iona peroveta tauna toana mo vadaeni. Bena ia ese a rakatanidia, e raka oho.$h$),
    -- MAT 17:21: Galilea ai
    ('ca13e362-f63e-4caa-aa15-20c850d93e2e'::uuid, $h$Ḡau tamona, ḡau inihetomadia ilulu-ohodia na dala ta lasi, ḡuriḡuri bona anivaga mo. Galilea ai$h$,
     $h$Ḡau tamona, ḡau inihetomadia ilulu-ohodia na dala ta lasi, ḡuriḡuri bona anivaga mo.$h$),
    -- MAT 18:14: Lalo ihatamodia herevadia
    ('9e7597d9-7310-4571-a2f2-7e6d37ffa24b'::uuid, $h$Unuhetomana, Tamamui guba ai e nohomu na se uramu ini memero-memero ta baine mase. Lalo ihatamodia herevadia$h$,
     $h$Unuhetomana, Tamamui guba ai e nohomu na se uramu ini memero-memero ta baine mase.$h$),
    -- MAT 21:17: Suke auna asi huahuana
    ('7193d774-bdc4-4838-b1f9-8a5c893801bc'::uuid, $h$Bena ia ese e rakatanidia, hanua badana amo e raka lasi, Betania ai eha mahuta. Suke auna asi huahuana$h$,
     $h$Bena ia ese e rakatanidia, hanua badana amo e raka lasi, Betania ai eha mahuta.$h$),
    -- MAT 21:22: Dubu Helaḡa ai
    ('b66d36c9-82c8-4bef-9ba2-6664c2e1294c'::uuid, $h$Ḡau iboudiai ḡuriḡuri ai ba noinoi, mai emui abi-dadama ida, vada bavabi. Dubu Helaḡa ai$h$,
     $h$Ḡau iboudiai ḡuriḡuri ai ba noinoi, mai emui abi-dadama ida, vada bavabi.$h$),
    -- MAT 22:14: Kaisara ena tax
    ('0f268cea-68a6-45d1-963f-41b1e0cbeac7'::uuid, $h$Badina be hutuma e boiridiamu, to gagadoi mo e abidia hidimu. Kaisara ena tax$h$,
     $h$Badina be hutuma e boiridiamu, to gagadoi mo e abidia hidimu.$h$),
    -- MAT 22:22: Tore-isi-lou herevadia
    ('aa6f5489-4a64-4c01-a9ff-8d63895edf76'::uuid, $h$Idia ese ena hereva e kamonai, e hoa; bena e rakatania, dauha ela. Tore-isi-lou herevadia$h$,
     $h$Idia ese ena hereva e kamonai, e hoa; bena e rakatania, dauha ela.$h$),
    -- MAT 24:41: Ba gima!
    ('e99696f3-ebf7-4c4e-bc08-7e441ba3772d'::uuid, $h$Hahine rarua uit igwadana nadina bae giroa, ta baine heabi oho, ta baine noho. Ba gima!$h$,
     $h$Hahine rarua uit igwadana nadina bae giroa, ta baine heabi oho, ta baine noho.$h$),
    -- MAT 25:13: Sivarai heḡereḡerena: Hesiai taudia moni e reguva
    ('0277949a-8219-491c-8d7a-1f4f8ae02a15'::uuid, $h$Taunabunai, ba gima: badina be dina bona hora na asi dibamui. Sivarai heḡereḡerena: Hesiai taudia moni e reguva$h$,
     $h$Taunabunai, ba gima: badina be dina bona hora na asi dibamui.$h$),
    -- MAT 26:35: Getesemane
    ('ec89107f-84a6-41f9-b85a-88498e0c514d'::uuid, $h$A Petro eto, Ena be oi ida baita mase hebou, tolau oi basina ḡoremu. Ena hahediba iboudiai danu unu mo e gwau toma. Getesemane$h$,
     $h$A Petro eto, Ena be oi ida baita mase hebou, tolau oi basina ḡoremu. Ena hahediba iboudiai danu unu mo e gwau toma.$h$),
    -- MAT 26:35: Getesemane
    ('f874799f-f17b-41bb-a326-d1add353da35'::uuid, $h$A Petro eto, Ena be oi ida baita mase hebou, tolau oi basina ḡoremu. Ena hahediba iboudiai danu unu mo e gwau toma. Getesemane$h$,
     $h$A Petro eto, Ena be oi ida baita mase hebou, tolau oi basina ḡoremu. Ena hahediba iboudiai danu unu mo e gwau toma.$h$),
    -- MAT 26:56: Iesu e hahemaoro henia hahelaḡa tauna badana vairanai
    ('4e4b0ff6-dbaf-477c-b18b-64cbbd89714c'::uuid, $h$A ini ḡau iboudiai vada e vara, peroveta taudia ese e tore herevadia ihamomokanilaidia. Bena ena hahediba iboudiai ese e heautania. Iesu e hahemaoro henia hahelaḡa tauna badana vairanai$h$,
     $h$A ini ḡau iboudiai vada e vara, peroveta taudia ese e tore herevadia ihamomokanilaidia. Bena ena hahediba iboudiai ese e heautania.$h$),
    -- MAT 26:68: Petro hatoi e heḡore
    ('3b0ff3ad-23d7-41b4-8132-98bd973b2235'::uuid, $h$Keriso e, a hamaoromai, daika ese e tutumumu? Petro hatoi e heḡore$h$,
     $h$Keriso e, a hamaoromai, daika ese e tutumumu?$h$),
    -- MAT 27:56: Iesu e guria
    ('773297c4-a6db-4f43-83fa-6a340f54b686'::uuid, $h$Haida bini: Maria, hane Magdala; bona Maria, Iakobo bona Iosef sinadia; bona Sebedeo natuna sinadia. Iesu e guria$h$,
     $h$Haida bini: Maria, hane Magdala; bona Maria, Iakobo bona Iosef sinadia; bona Sebedeo natuna sinadia.$h$),
    -- MIC 5:1: Hahemauri Tauna Betelehem amo
    ('039d2012-7fa6-4689-81f8-f78dbce3edf2'::uuid, $h$Harihari vada e maḡumu ahu; vada e kouda heḡege; hebota auna amo Israel lohiana vahana e botaiamu. Hahemauri Tauna Betelehem amo$h$,
     $h$Harihari vada e maḡumu ahu; vada e kouda heḡege; hebota auna amo Israel lohiana vahana e botaiamu.$h$),
    -- MIC 5:1: Hahemauri Tauna Betelehem amo
    ('7f4ec3d1-e9c2-4fcb-bb5f-527ad508ed35'::uuid, $h$Harihari vada e maḡumu ahu; vada e kouda heḡege; hebota auna amo Israel lohiana vahana e botaiamu. Hahemauri Tauna Betelehem amo$h$,
     $h$Harihari vada e maḡumu ahu; vada e kouda heḡege; hebota auna amo Israel lohiana vahana e botaiamu.$h$),
    -- MRK 1:13: Iesu ena ḡaukara e matamaia Galilea ai
    ('04d55960-e798-4c1b-b6ef-7bdf6b11dac5'::uuid, $h$Dina hari-ahuitano ḡaḡaena ai e nohova, Satana ese e dibaḡaniava. Ia na hekori boromadia ida e nohova, to aneru ese ia isiaina e lao heniva. Iesu ena ḡaukara e matamaia Galilea ai$h$,
     $h$Dina hari-ahuitano ḡaḡaena ai e nohova, Satana ese e dibaḡaniava. Ia na hekori boromadia ida e nohova, to aneru ese ia isiaina e lao heniva.$h$),
    -- MRK 1:13: Iesu ena ḡaukara e matamaia Galilea ai
    ('e5a5ef57-5f0a-4f91-86cf-a5aa0461b386'::uuid, $h$Dina hari-ahuitano ḡaḡaena ai e nohova, Satana ese e dibaḡaniava. Ia na hekori boromadia ida e nohova, to aneru ese ia isiaina e lao heniva. Iesu ena ḡaukara e matamaia Galilea ai$h$,
     $h$Dina hari-ahuitano ḡaḡaena ai e nohova, Satana ese e dibaḡaniava. Ia na hekori boromadia ida e nohova, to aneru ese ia isiaina e lao heniva.$h$),
    -- MRK 1:34: lesu Galilea hanuadia ai e haroro
    ('163b0212-335e-4586-b07b-3b0cb917045b'::uuid, $h$Bena gorere idau-idau taudia hutuma ia esee hamauridia, bona lauma dikadia e luludia lasi; a lauma dikadia na e gwaudia tao, basie hereva, badina be idia dibadia ia. lesu Galilea hanuadia ai e haroro$h$,
     $h$Bena gorere idau-idau taudia hutuma ia esee hamauridia, bona lauma dikadia e luludia lasi; a lauma dikadia na e gwaudia tao, basie hereva, badina be idia dibadia ia.$h$),
    -- MRK 2:17: Iesu ena hahediha asie anivaga
    ('27edeb71-ca84-44c8-884b-86a781b89d98'::uuid, $h$Iesu e kamonai, bena e hamaorodia, eto, Goada taudia ese muramura tauna basie tahua, a gorere taudia hari; lau danu nama, dia kara maoromaoro taudia iboiridia totona, a kara dika taudia hari. Iesu ena hahediha asie anivaga$h$,
     $h$Iesu e kamonai, bena e hamaorodia, eto, Goada taudia ese muramura tauna basie tahua, a gorere taudia hari; lau danu nama, dia kara maoromaoro taudia iboiridia totona, a kara dika taudia hari.$h$),
    -- MRK 4:20: Diari herevadia
    ('3f0fe601-7bbd-4fc1-86ae-7d69777b8c96'::uuid, $h$A tano namona ai e moru ḡaudia be taunimanima hereva e kamonairnu, bena lalodia ai e abia daemu, taunabunai huahuana e dobimu, ta toi-ahui, ta tauratoi-ahui, ma ta sinahu-ta. Diari herevadia$h$,
     $h$A tano namona ai e moru ḡaudia be taunimanima hereva e kamonairnu, bena lalodia ai e abia daemu, taunabunai huahuana e dobimu, ta toi-ahui, ta tauratoi-ahui, ma ta sinahu-ta.$h$),
    -- MRK 5:20: Iairo natuna
    ('0ea60815-3ecf-4630-9b00-68bdc71cbc36'::uuid, $h$Bena ia na ela, Hanua Gwauta tanona idoinai Iesu ena kara ienai e harorolai; taunabunai taunimanima iboudiai e hoa. Iairo natuna$h$,
     $h$Bena ia na ela, Hanua Gwauta tanona idoinai Iesu ena kara ienai e harorolai; taunabunai taunimanima iboudiai e hoa.$h$),
    -- MRK 8:10: Dalmanuta ai
    ('6b684e73-34f7-4ada-9005-54b40288d5a8'::uuid, $h$Bena ena hahediba ida vanaḡi ai ma e gui, Dalmanuta tanona ela. Dalmanuta ai$h$,
     $h$Bena ena hahediba ida vanaḡi ai ma e gui, Dalmanuta tanona ela.$h$),
    -- MRK 9:1: Iesu oromana eha idaua
    ('a3b0e820-a4a6-492f-be97-28af49e647b2'::uuid, $h$Ma e hamaorodia, eto, Na hamaoromui momokanimu, haida o ini gigini na basie mase, ela bona Dirava ena basileia mai siahuna ida baine kau bae itaia. Iesu oromana eha idaua$h$,
     $h$Ma e hamaorodia, eto, Na hamaoromui momokanimu, haida o ini gigini na basie mase, ela bona Dirava ena basileia mai siahuna ida baine kau bae itaia.$h$),
    -- MRK 10:12: Iesu ese maraḡidia e hanamodia
    ('ba84da1e-6554-4065-b242-d73ed65d1c49'::uuid, $h$bona adavana bainedihotania bena tau ta baine adavaia hahinena danu heuda-hanai hahinena. Iesu ese maraḡidia e hanamodia$h$,
     $h$bona adavana bainedihotania bena tau ta baine adavaia hahinena danu heuda-hanai hahinena.$h$),
    -- MRK 10:45: leriko ai
    ('a5d78357-d27a-43b9-8d6e-e00d67da1209'::uuid, $h$Badina be Taunimanima Natuna ema, dia haida ese ia isiaina bae lao henia totona, a ia hari idia isiaidia baine lao heni, bona ena mauri baine henia, hutuma ihamauridia. leriko ai$h$,
     $h$Badina be Taunimanima Natuna ema, dia haida ese ia isiaina bae lao henia totona, a ia hari idia isiaidia baine lao heni, bona ena mauri baine henia, hutuma ihamauridia.$h$),
    -- MRK 12:40: Vabu ena boubou monina
    ('5051135c-b15e-48c6-bfb9-640c876cfd67'::uuid, $h$A idia ese vabu edia ruma e ha-ogoḡamidia, bona edia ḡuriḡuri e hadaudau, taunimanima ikoilaidia. Idia na dava metaudia do bae abi. Vabu ena boubou monina$h$,
     $h$A idia ese vabu edia ruma e ha-ogoḡamidia, bona edia ḡuriḡuri e hadaudau, taunimanima ikoilaidia. Idia na dava metaudia do bae abi.$h$),
    -- MRK 13:27: Heteva heḡereḡeredia: Ba gima!
    ('6526e8c7-ffd7-4190-991a-0d5eb7235a1b'::uuid, $h$Bena ia ese ena anerubaine siaidia lao, lai haniosi gabudia amo, bona tanobada dokona ela bona guba dokona amo, e abidia hidi taudia na bae gogodia. Heteva heḡereḡeredia: Ba gima!$h$,
     $h$Bena ia ese ena anerubaine siaidia lao, lai haniosi gabudia amo, bona tanobada dokona ela bona guba dokona amo, e abidia hidi taudia na bae gogodia.$h$),
    -- MRK 13:27: Heteva heḡereḡeredia: Ba gima!
    ('ae31da0d-6fa3-46c9-970f-ead9392a66ed'::uuid, $h$Bena ia ese ena anerubaine siaidia lao, lai haniosi gabudia amo, bona tanobada dokona ela bona guba dokona amo, e abidia hidi taudia na bae gogodia. Heteva heḡereḡeredia: Ba gima!$h$,
     $h$Bena ia ese ena anerubaine siaidia lao, lai haniosi gabudia amo, bona tanobada dokona ela bona guba dokona amo, e abidia hidi taudia na bae gogodia.$h$),
    -- MRK 15:15: Iesu e ḡonaḡonalaia
    ('3cbd1c3b-27e5-4db9-b589-a5c649a299b5'::uuid, $h$Taunabunai, Pilato na aru taudia ihamarumarudia urana e urava dainai, ia ese Baraba e ruhaia nege, a Iesu na e dadabaia, bena e henidia, bae hasatauroa. Iesu e ḡonaḡonalaia$h$,
     $h$Taunabunai, Pilato na aru taudia ihamarumarudia urana e urava dainai, ia ese Baraba e ruhaia nege, a Iesu na e dadabaia, bena e henidia, bae hasatauroa.$h$),
    -- NEH 9:37: Israel taudia na e ḡwau hamata taravatu bae badinaia
    ('561b9128-1043-4852-9f9c-5931d2a31210'::uuid, $h$Hari pavapava, emai kara dika amo daemai ai vada o atodia taudia, ese ia anina herea-daena e abiamu; idia na mai siahudia danu, tau-animai bona emai ubu-ubu gaudia bae biagudia, edia ura heḡereḡerena ai; bona ai na vada a hekwarahi mase. Israel taudia na e ḡwau hamata taravatu bae badinaia$h$,
     $h$Hari pavapava, emai kara dika amo daemai ai vada o atodia taudia, ese ia anina herea-daena e abiamu; idia na mai siahudia danu, tau-animai bona emai ubu-ubu gaudia bae biagudia, edia ura heḡereḡerena ai; bona ai na vada a hekwarahi mase.$h$),
    -- NEH 9:37: Israel taudia na e ḡwau hamata taravatu bae badinaia
    ('8e132eb6-3dc6-4044-9def-3f489566cc3d'::uuid, $h$Hari pavapava, emai kara dika amo daemai ai vada o atodia taudia, ese ia anina herea-daena e abiamu; idia na mai siahudia danu, tau-animai bona emai ubu-ubu gaudia bae biagudia, edia ura heḡereḡerena ai; bona ai na vada a hekwarahi mase. Israel taudia na e ḡwau hamata taravatu bae badinaia$h$,
     $h$Hari pavapava, emai kara dika amo daemai ai vada o atodia taudia, ese ia anina herea-daena e abiamu; idia na mai siahudia danu, tau-animai bona emai ubu-ubu gaudia bae biagudia, edia ura heḡereḡerena ai; bona ai na vada a hekwarahi mase.$h$),
    -- NUM 3:39: Roboa mamaruanedia ibololaidia
    ('c3add738-b05e-4083-b81b-152d4f0f4659'::uuid, $h$Levi taudia, Mose bona Aaron ese iduhu ta ta amo e duahidia, Iehova ena haheḡani dainai, ibouboudiai, hua ta e hanaia amo, na 22,000. Roboa mamaruanedia ibololaidia$h$,
     $h$Levi taudia, Mose bona Aaron ese iduhu ta ta amo e duahidia, Iehova ena haheḡani dainai, ibouboudiai, hua ta e hanaia amo, na 22,000.$h$),
    -- NUM 10:10: Israel taudia Sinai e rakatania
    ('ec3e0976-2192-42b2-a20f-04c444da7627'::uuid, $h$Emui moale dinadia ai danu, bona emui aria dinadia ai, eiava hua matamata negadia ai, emui ḡole-oho bouboudia bona emui herohemaino bouboudia ba hahelaḡadiamai kibi ihiriridia ida; unu amo emui Dirava ese baine lalomui tao. Lau binai Iehova, emui Dirava. Israel taudia Sinai e rakatania$h$,
     $h$Emui moale dinadia ai danu, bona emui aria dinadia ai, eiava hua matamata negadia ai, emui ḡole-oho bouboudia bona emui herohemaino bouboudia ba hahelaḡadiamai kibi ihiriridia ida; unu amo emui Dirava ese baine lalomui tao. Lau binai Iehova, emui Dirava.$h$),
    -- NUM 21:9: Israel ma e laolao
    ('41b20fe6-e4da-4baf-9e6e-c81a8d97f825'::uuid, $h$Taunabunai, Mose ese gaigai laulauna ta, auri labora-labora amo e koroa, bona au-tubua dorina ai e kapaia kau, bena gaigai ese e koridia taudia ese una auri labora-labora gaigaina e raraiatao, bena vada e mauri. Israel ma e laolao$h$,
     $h$Taunabunai, Mose ese gaigai laulauna ta, auri labora-labora amo e koroa, bona au-tubua dorina ai e kapaia kau, bena gaigai ese e koridia taudia ese una auri labora-labora gaigaina e raraiatao, bena vada e mauri.$h$),
    -- NUM 21:15: Israel edia Ane
    ('6fe4ffe1-444d-4244-9533-e121db413a6b'::uuid, $h$Koura ege-egedia Ela bona Ara ena noho gabuna, Bona Moab tanona hetoana. Israel edia Ane$h$,
     $h$Koura ege-egedia Ela bona Ara ena noho gabuna, Bona Moab tanona hetoana.$h$),
    -- NUM 21:20: Israel ese Sihon bona Og e hadareredia
    ('14e8d12c-867c-434c-b41a-350f5a2641fa'::uuid, $h$Bamoto amo ela bona koura ta Moab kahana ai; ma unu amo ela bona Pisga ororona dorina: unu amo tano ḡaḡaena e roha tari lao. Israel ese Sihon bona Og e hadareredia$h$,
     $h$Bamoto amo ela bona koura ta Moab kahana ai; ma unu amo ela bona Pisga ororona dorina: unu amo tano ḡaḡaena e roha tari lao.$h$),
    -- NUM 21:20: Israel ese Sihon bona Og e hadareredia
    ('9a5df309-1fb5-49a5-bcd8-67675db96d00'::uuid, $h$Bamoto amo ela bona koura ta Moab kahana ai; ma unu amo ela bona Pisga ororona dorina: unu amo tano ḡaḡaena e roha tari lao. Israel ese Sihon bona Og e hadareredia$h$,
     $h$Bamoto amo ela bona koura ta Moab kahana ai; ma unu amo ela bona Pisga ororona dorina: unu amo tano ḡaḡaena e roha tari lao.$h$),
    -- NUM 21:20: Israel ese Sihon bona Og e hadareredia
    ('e887a5b3-85af-4d52-81ae-0112aab47389'::uuid, $h$Bamoto amo ela bona koura ta Moab kahana ai; ma unu amo ela bona Pisga ororona dorina: unu amo tano ḡaḡaena e roha tari lao. Israel ese Sihon bona Og e hadareredia$h$,
     $h$Bamoto amo ela bona koura ta Moab kahana ai; ma unu amo ela bona Pisga ororona dorina: unu amo tano ḡaḡaena e roha tari lao.$h$),
    -- NUM 22:20: Balaam ena a doniki e hereva
    ('de6a9b2e-dfc6-4d0d-b835-eb9c7190c7c5'::uuid, $h$Bena hanuaboi ai Dirava ese Balaam e hahedinarai henia, eto, Ini taunimanima) ima na oi iboirimu vada ema. Vadaeni, a tore isi, idia ida baola; a lau ese baina hamaoromu heḡereḡerena ai mo ba karaia. Balaam ena a doniki e hereva$h$,
     $h$Bena hanuaboi ai Dirava ese Balaam e hahedinarai henia, eto, Ini taunimanima) ima na oi iboirimu vada ema. Vadaeni, a tore isi, idia ida baola; a lau ese baina hamaoromu heḡereḡerena ai mo ba karaia.$h$),
    -- NUM 26:51: Tano iharina
    ('45d469fb-0410-44e4-b190-6ab0b19425ee'::uuid, $h$Israel taudia ibouboudiai e duahidia be 601,730. Tano iharina$h$,
     $h$Israel taudia ibouboudiai e duahidia be 601,730.$h$),
    -- NUM 28:10: Hua matamata Bouboudia
    ('1c6754da-1efd-471e-974f-e345fd1b1cbd'::uuid, $h$Dina Helaḡa iboudiai ḡole-oho bouboudia unu ba heni toma, dina kavakava ena ḡole-oho boubouna bonaena inuinu boubouna ida ba heni hebou. Hua matamata Bouboudia$h$,
     $h$Dina Helaḡa iboudiai ḡole-oho bouboudia unu ba heni toma, dina kavakava ena ḡole-oho boubouna bonaena inuinu boubouna ida ba heni hebou.$h$),
    -- NUM 28:25: Taboro Bouboudia
    ('1304dc1b-ab22-4d8e-bc65-1dcd464f038e'::uuid, $h$Dinaihahituna ai hebou helaḡana bavabia, una dina ai ḡaukara badana ta basio karaia. Taboro Bouboudia$h$,
     $h$Dinaihahituna ai hebou helaḡana bavabia, una dina ai ḡaukara badana ta basio karaia.$h$),
    -- PHP 2:24: Epafrodito be vasimu
    ('92b7a84a-dd2a-455a-b904-01b11126cb6e'::uuid, $h$A Lohiabada na abidadama heniamu, nega basine daudau lau danu baina vasi. Epafrodito be vasimu$h$,
     $h$A Lohiabada na abidadama heniamu, nega basine daudau lau danu baina vasi.$h$),
    -- REV 21:8: Ierusalem matamatana
    ('446b6ce1-9b01-4989-a53b-cc2c220acba0'::uuid, $h$A gari taudia, asie kamonai taudia, kara bodaḡa taudia, ala-ala taudia, babalau taudia, kaivakuku e toma henidia diho taudia, koikoi taudia, iboudiai ahudia na lahi bona teio gohuna: mase iharuana bunai. Ierusalem matamatana$h$,
     $h$A gari taudia, asie kamonai taudia, kara bodaḡa taudia, ala-ala taudia, babalau taudia, kaivakuku e toma henidia diho taudia, koikoi taudia, iboudiai ahudia na lahi bona teio gohuna: mase iharuana bunai.$h$),
    -- REV 22:5: Lohiabada be maimu
    ('d5a96872-3335-4bb7-abdc-ecb2d876f996'::uuid, $h$Hanua na basine boi lou, bona lamepa bona dina diaridia na herevadia, badina be Lohiabada Dirava ese baine hadiaridia; bona bae lohia hanihanai. Lohiabada be maimu$h$,
     $h$Hanua na basine boi lou, bona lamepa bona dina diaridia na herevadia, badina be Lohiabada Dirava ese baine hadiaridia; bona bae lohia hanihanai.$h$),
    -- ROM 1:7: Hahenamo herevadia
    ('955c7e87-f511-4b65-8628-3adf41263bea'::uuid, $h$Dirava ese e ura henimuimu taumui Roma ai o nohomu, helaḡa taumui e gwauraimuimu, ba namo; Tamada Dirava bona Lohiabada Iesu Keriso edia anlo harihari-bada bona maino bavabi. Hahenamo herevadia$h$,
     $h$Dirava ese e ura henimuimu taumui Roma ai o nohomu, helaḡa taumui e gwauraimuimu, ba namo; Tamada Dirava bona Lohiabada Iesu Keriso edia anlo harihari-bada bona maino bavabi.$h$),
    -- ROM 7:6: Taravatu ena namo be dahaka?
    ('4ebcd1e8-fe99-4d51-a5a0-8c2ac9b0f589'::uuid, $h$A harihari taravatu ese vada e kahuda nege, e dogoda taova ḡauna enai vada ta mase na heto; taunabunai harihari eda hesiai ilao-henina na lauma dainai, dia nega gunadia ai e tore herevadia daidiai. Taravatu ena namo be dahaka?$h$,
     $h$A harihari taravatu ese vada e kahuda nege, e dogoda taova ḡauna enai vada ta mase na heto; taunabunai harihari eda hesiai ilao-henina na lauma dainai, dia nega gunadia ai e tore herevadia daidiai.$h$),
    -- ROM 7:6: Taravatu ena namo be dahaka?
    ('9fe3b436-81ed-4c4c-b9f8-f81d4f6c496e'::uuid, $h$A harihari taravatu ese vada e kahuda nege, e dogoda taova ḡauna enai vada ta mase na heto; taunabunai harihari eda hesiai ilao-henina na lauma dainai, dia nega gunadia ai e tore herevadia daidiai. Taravatu ena namo be dahaka?$h$,
     $h$A harihari taravatu ese vada e kahuda nege, e dogoda taova ḡauna enai vada ta mase na heto; taunabunai harihari eda hesiai ilao-henina na lauma dainai, dia nega gunadia ai e tore herevadia daidiai.$h$),
    -- ROM 15:13: Egu ḡaukara bona egu laolao
    ('8e4a5c56-f324-4dbf-82db-72fc903ecc22'::uuid, $h$Helaro Diravana ese emui abidadama dainai moale bona maino idoinai baine hahonulaimui, Lauma Helaḡa siahuna amo baine habadaia. Egu ḡaukara bona egu laolao$h$,
     $h$Helaro Diravana ese emui abidadama dainai moale bona maino idoinai baine hahonulaimui, Lauma Helaḡa siahuna amo baine habadaia.$h$),
    -- TIT 1:9: Hahediba koikoi
    ('8042dda8-6a0b-42ce-bb9f-26567fed0a6a'::uuid, $h$Hereva momokani baine abi tarika-tarika, vada e hadibalaia heḡereḡerena; unu amo baine heḡereḡere, hahediba herevadia maoromaorodia amo taunimanima lalodia baine hagoadadia bona hereva momokani e laoahumu taudia baine nanaudia. Hahediba koikoi$h$,
     $h$Hereva momokani baine abi tarika-tarika, vada e hadibalaia heḡereḡerena; unu amo baine heḡereḡere, hahediba herevadia maoromaorodia amo taunimanima lalodia baine hagoadadia bona hereva momokani e laoahumu taudia baine nanaudia.$h$),
    -- TIT 1:9: Hahediba koikoi
    ('9ab0acdf-aeb1-4799-b079-4548bd922157'::uuid, $h$Hereva momokani baine abi tarika-tarika, vada e hadibalaia heḡereḡerena; unu amo baine heḡereḡere, hahediba herevadia maoromaorodia amo taunimanima lalodia baine hagoadadia bona hereva momokani e laoahumu taudia baine nanaudia. Hahediba koikoi$h$,
     $h$Hereva momokani baine abi tarika-tarika, vada e hadibalaia heḡereḡerena; unu amo baine heḡereḡere, hahediba herevadia maoromaorodia amo taunimanima lalodia baine hagoadadia bona hereva momokani e laoahumu taudia baine nanaudia.$h$),
    -- ZEC 1:6: Peroveta tauna ena matu-hanai gini-gunana
    ('9b710815-5983-4c46-be3f-03913fb21a98'::uuid, $h$A egu hereva bona egu taravatu, egu hesiai peroveta taudia na haḡanilaidia gaudia, ese tamamui e lasidia tao ani? Una dainai idia na e helalo kerehai, eto, Iehova Sabaota ese e laloa hata eda dala bona eda kara heḡereḡeredia ai baine kara henida; bena unu vada e kara henida toma. Peroveta tauna ena matu-hanai gini-gunana$h$,
     $h$A egu hereva bona egu taravatu, egu hesiai peroveta taudia na haḡanilaidia gaudia, ese tamamui e lasidia tao ani? Una dainai idia na e helalo kerehai, eto, Iehova Sabaota ese e laloa hata eda dala bona eda kara heḡereḡeredia ai baine kara henida; bena unu vada e kara henida toma.$h$),
    -- ZEC 1:17: Peroveto tauna ena mata-hanai iharuana
    ('b682e2bd-34db-4ddc-b2d0-3ee9fa4922ca'::uuid, $h$Ma ba boi lolo, baoto, Iehova Sabaota ini e gwau tomamu: Egu hanua badadia na noho-namo ai ma bae honu honu dae, bona Iehova ese Siona ma baine hahealo henia lou, bona Ierusalem ma baine abia hidi lou. Peroveto tauna ena mata-hanai iharuana$h$,
     $h$Ma ba boi lolo, baoto, Iehova Sabaota ini e gwau tomamu: Egu hanua badadia na noho-namo ai ma bae honu honu dae, bona Iehova ese Siona ma baine hahealo henia lou, bona Ierusalem ma baine abia hidi lou.$h$),
    -- ZEC 5:4: Peroveta tauna ena mata-hanai ihahituna
    ('3e177f78-28b9-498a-8b22-4ae71cc4befb'::uuid, $h$Iehova Sabaota na e tomu: Lau ese baina siaia lao, henao tauna ena ruma lalonai baine vareai bona lau ladagu ai e gwau hamata koikoimu tauna ena ruma lalonai danu; bena ena ruma ai baine mia ela bona baine ha-olea, au bona nadi danu baine ha-oredia. Peroveta tauna ena mata-hanai ihahituna$h$,
     $h$Iehova Sabaota na e tomu: Lau ese baina siaia lao, henao tauna ena ruma lalonai baine vareai bona lau ladagu ai e gwau hamata koikoimu tauna ena ruma lalonai danu; bena ena ruma ai baine mia ela bona baine ha-olea, au bona nadi danu baine ha-oredia.$h$),
    -- ZEC 6:8: Iosua kwarana ihavavalaina
    ('ec8413cb-51e8-47c3-a1c4-c7c8d1533228'::uuid, $h$Bena ia ese e boi henigu, eto, A itaia, mirigini kahana vada e lao heniamu taudia ese Laumagu vada e halagaia ani, una mirigini kahana tanona ai. Iosua kwarana ihavavalaina$h$,
     $h$Bena ia ese e boi henigu, eto, A itaia, mirigini kahana vada e lao heniamu taudia ese Laumagu vada e halagaia ani, una mirigini kahana tanona ai.$h$),
    -- ZEC 7:7: Gwau-edeede davana
    ('348a301f-a1f9-4c06-934b-4c426cc271df'::uuid, $h$Ierusalem bona ena hetabira hanuadia na e noholaidiava mai namodia ida, bona diho kahana bona taora kahadia danue noholaidiava, negana ai ini hereva na Iehova ese peroveta taudia gunadia ududia amo e gwaurai, ani? Gwau-edeede davana$h$,
     $h$Ierusalem bona ena hetabira hanuadia na e noholaidiava mai namodia ida, bona diho kahana bona taora kahadia danue noholaidiava, negana ai ini hereva na Iehova ese peroveta taudia gunadia ududia amo e gwaurai, ani?$h$),
    -- ZEC 9:8: Siona pavapavana
    ('f0f329f2-3948-4cb4-99f4-2698b86c8e9b'::uuid, $h$Bena egu ruma ai baina kone noho, baina gimaia, ta na basine raka lao raka mai helaoreana; hahehisi tauna ta ese basine hahebolodia uru lou, badina be harihari lau sibogu matagu amo na heitamu. Siona pavapavana$h$,
     $h$Bena egu ruma ai baina kone noho, baina gimaia, ta na basine raka lao raka mai helaoreana; hahehisi tauna ta ese basine hahebolodia uru lou, badina be harihari lau sibogu matagu amo na heitamu.$h$),
    -- ZEC 11:3: Mamoe ireḡudia taudia asi namodia
    ('6f7b3fb0-248a-4c65-9ffc-45370e072fef'::uuid, $h$A hakala, mamoe ireḡudia taudia na e taimu! Badina be hairaidia vada e dika vaitani. A hakala, leona na e ḡoumu! Badina be Ioridane udana vada e hakorua. Mamoe ireḡudia taudia asi namodia$h$,
     $h$A hakala, mamoe ireḡudia taudia na e taimu! Badina be hairaidia vada e dika vaitani. A hakala, leona na e ḡoumu! Badina be Ioridane udana vada e hakorua.$h$),
    -- ZEC 13:6: Iehova ena mamoe ireḡudia tauna irahu-masena
    ('9810ff13-601e-44d8-8fc7-037b026ab693'::uuid, $h$Bena ta ese bema nanadaidia, bema toma “Ene dorumui berodia be dahaka?”, idia baeto “Ini bero na turamai edia ruma ai a davari”. Iehova ena mamoe ireḡudia tauna irahu-masena$h$,
     $h$Bena ta ese bema nanadaidia, bema toma “Ene dorumui berodia be dahaka?”, idia baeto “Ini bero na turamai edia ruma ai a davari”.$h$)
)
UPDATE public.words w
SET example_motu = f.new_value
FROM fixes f
WHERE w.id = f.id
  AND w.example_motu = f.old_value;

-- --- example_english (20 rows) ---

WITH fixes(id, old_value, new_value) AS (
  VALUES
    -- PSA 119:96: MEM
    ('f26600c4-5ac3-485e-8850-b37624b0b04b'::uuid, $h$I have seen a limit to all perfection, but your commands are boundless. MEM$h$,
     $h$I have seen a limit to all perfection, but your commands are boundless.$h$),
    -- PSA 119:128: PE
    ('49c49b6f-66b7-482a-b0d6-cdf8f8e9aa69'::uuid, $h$Therefore I consider all of your precepts to be right. I hate every false way. PE$h$,
     $h$Therefore I consider all of your precepts to be right. I hate every false way.$h$),
    -- SNG 1:7: Lover
    ('fdfb4e0e-ca30-45fc-8f9d-2a43ff1b08d8'::uuid, $h$Tell me, you whom my soul loves, where you graze your flock, where you rest them at noon; for why should I be as one who is veiled beside the flocks of your companions? Lover$h$,
     $h$Tell me, you whom my soul loves, where you graze your flock, where you rest them at noon; for why should I be as one who is veiled beside the flocks of your companions?$h$),
    -- SNG 1:10: Friends
    ('f341d19e-01aa-4e2f-b937-7d184c1c4a25'::uuid, $h$Your cheeks are beautiful with earrings, your neck with strings of jewels. Friends$h$,
     $h$Your cheeks are beautiful with earrings, your neck with strings of jewels.$h$),
    -- SNG 1:11: Beloved
    ('59264d88-7041-4f06-b744-7b68564cc362'::uuid, $h$We will make you earrings of gold, with studs of silver. Beloved$h$,
     $h$We will make you earrings of gold, with studs of silver.$h$),
    -- SNG 1:14: Lover
    ('1065be12-c5d3-483c-8d40-11cdc430825d'::uuid, $h$My beloved is to me a cluster of henna blossoms from the vineyards of En Gedi. Lover$h$,
     $h$My beloved is to me a cluster of henna blossoms from the vineyards of En Gedi.$h$),
    -- SNG 1:14: Lover
    ('59740f12-4aed-4129-a0d6-7032116dfe8e'::uuid, $h$My beloved is to me a cluster of henna blossoms from the vineyards of En Gedi. Lover$h$,
     $h$My beloved is to me a cluster of henna blossoms from the vineyards of En Gedi.$h$),
    -- SNG 1:14: Lover
    ('b63a427d-8aed-430d-9331-d46fc08f1631'::uuid, $h$My beloved is to me a cluster of henna blossoms from the vineyards of En Gedi. Lover$h$,
     $h$My beloved is to me a cluster of henna blossoms from the vineyards of En Gedi.$h$),
    -- SNG 1:16: Lover
    ('1d0fd7cc-02cd-4bae-9698-836ecec4c43d'::uuid, $h$Behold, you are beautiful, my beloved, yes, pleasant; and our couch is verdant. Lover$h$,
     $h$Behold, you are beautiful, my beloved, yes, pleasant; and our couch is verdant.$h$),
    -- SNG 2:1: Lover
    ('d14c0279-dfa4-482c-8cab-a7897db0755d'::uuid, $h$I am a rose of Sharon, a lily of the valleys. Lover$h$,
     $h$I am a rose of Sharon, a lily of the valleys.$h$),
    -- SNG 2:1: Lover
    ('f7f780dc-5a63-47b7-982a-d8e0b590e030'::uuid, $h$I am a rose of Sharon, a lily of the valleys. Lover$h$,
     $h$I am a rose of Sharon, a lily of the valleys.$h$),
    -- SNG 2:2: Beloved
    ('bb2531fa-be8e-481b-8439-f26ac1237f72'::uuid, $h$As a lily among thorns, so is my love among the daughters. Beloved$h$,
     $h$As a lily among thorns, so is my love among the daughters.$h$),
    -- SNG 2:15: Beloved
    ('5a699736-4253-4017-954e-c784e068756d'::uuid, $h$Catch for us the foxes, the little foxes that plunder the vineyards; for our vineyards are in blossom. Beloved$h$,
     $h$Catch for us the foxes, the little foxes that plunder the vineyards; for our vineyards are in blossom.$h$),
    -- SNG 2:15: Beloved
    ('5fe3617a-6563-4aa3-b552-c1e0005161b9'::uuid, $h$Catch for us the foxes, the little foxes that plunder the vineyards; for our vineyards are in blossom. Beloved$h$,
     $h$Catch for us the foxes, the little foxes that plunder the vineyards; for our vineyards are in blossom.$h$),
    -- SNG 4:15: Beloved
    ('11d70713-7ef6-4f1d-bd07-400f88317224'::uuid, $h$a fountain of gardens, a well of living waters, flowing streams from Lebanon. Beloved$h$,
     $h$a fountain of gardens, a well of living waters, flowing streams from Lebanon.$h$),
    -- SNG 4:15: Beloved
    ('e8f550af-4f68-4b07-a073-3d8e2ab6a979'::uuid, $h$a fountain of gardens, a well of living waters, flowing streams from Lebanon. Beloved$h$,
     $h$a fountain of gardens, a well of living waters, flowing streams from Lebanon.$h$),
    -- SNG 5:1: Friends / Beloved
    ('a7c91f4d-b423-4fb3-b425-eac9ae904a05'::uuid, $h$I have come into my garden, my sister, my bride. I have gathered my myrrh with my spice; I have eaten my honeycomb with my honey; I have drunk my wine with my milk. Friends Eat, friends! Drink, yes, drink abundantly, beloved. Beloved$h$,
     $h$I have come into my garden, my sister, my bride. I have gathered my myrrh with my spice; I have eaten my honeycomb with my honey; I have drunk my wine with my milk. Eat, friends! Drink, yes, drink abundantly, beloved.$h$),
    -- SNG 6:13: Lover
    ('5b2a7b06-1f1e-4c6f-9284-d4538da25071'::uuid, $h$Return, return, Shulammite! Return, return, that we may gaze at you. Lover Why do you desire to gaze at the Shulammite, as at the dance of Mahanaim?$h$,
     $h$Return, return, Shulammite! Return, return, that we may gaze at you. Why do you desire to gaze at the Shulammite, as at the dance of Mahanaim?$h$),
    -- SNG 7:9: Beloved
    ('ed558520-e7fa-4d98-85cb-4db12576974c'::uuid, $h$Your mouth is like the best wine, that goes down smoothly for my beloved, gliding through the lips of those who are asleep. Beloved$h$,
     $h$Your mouth is like the best wine, that goes down smoothly for my beloved, gliding through the lips of those who are asleep.$h$),
    -- SNG 8:5: Beloved
    ('2e9bf2ce-afa5-4e08-964c-d4646db61644'::uuid, $h$Who is this who comes up from the wilderness, leaning on her beloved? Beloved Under the apple tree I awakened you. There your mother conceived you. There she was in labor and bore you.$h$,
     $h$Who is this who comes up from the wilderness, leaning on her beloved? Under the apple tree I awakened you. There your mother conceived you. There she was in labor and bore you.$h$)
)
UPDATE public.words w
SET example_english = f.new_value
FROM fixes f
WHERE w.id = f.id
  AND w.example_english = f.old_value;

ALTER TABLE public.words ENABLE TRIGGER update_words_updated_at;
