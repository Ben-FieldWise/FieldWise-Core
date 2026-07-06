//
//  HelpFAQModel.swift
//  Student Fieldwork App
//
//  Content for the Help & FAQ sheet, reachable via the (?) icon on
//  every tab. Organised by section so it can render as a grouped list
//  with expand/collapse per question, similar in spirit to the
//  GeoCard-based disclosure patterns used elsewhere in the app.
//

import Foundation

struct FAQItem: Identifiable {
    let id = UUID()
    let question: String
    let answer: String
}

struct FAQSection: Identifiable {
    let id = UUID()
    let title: String
    let iconName: String
    let items: [FAQItem]
}

let faqSections: [FAQSection] = [
    FAQSection(
        title: "Getting started",
        iconName: "hand.wave.fill",
        items: [
            FAQItem(
                question: "What does each tab do?",
                answer: "Plan — build a 6-step fieldwork plan before you go. Landscapes — reference material on rocks, soils, landforms, field tests, and human impact. Weather — live conditions and a fieldwork suitability check. Map — an interactive GIS map plus a compass. Report — where you record field data, fill in survey forms, write your report, and export everything to PDF."
            ),
            FAQItem(
                question: "Can I see the welcome screen again?",
                answer: "Yes — scroll to the bottom of this Help screen and tap \"Show welcome screen again\"."
            ),
            FAQItem(
                question: "Does the app work without an internet connection?",
                answer: "Most of it does — Plan, Landscapes, and Report all work fully offline since they're stored on your device. Weather and the live map tiles need a connection to fetch current data, but anything you've already loaded stays visible until you back out of that screen."
            )
        ]
    ),
    FAQSection(
        title: "Plan",
        iconName: "clipboard.fill",
        items: [
            FAQItem(
                question: "What are the 6 steps in the planning wizard?",
                answer: "Aims & location, Equipment, Data methods, Safety, Recording, and a final pre-departure checklist. You can move between steps using the arrows at the bottom of each screen, and your answers are saved automatically as you go."
            ),
            FAQItem(
                question: "Does my plan get saved automatically?",
                answer: "Yes — there's no save button. Every field updates your saved plan as soon as you type or select something, so you can close the app at any point and pick up where you left off."
            )
        ]
    ),
    FAQSection(
        title: "Landscapes",
        iconName: "mountain.2.fill",
        items: [
            FAQItem(
                question: "What's in the Landscapes tab?",
                answer: "Five sections, switchable from the bar at the top: Rocks (igneous, sedimentary, metamorphic), Soils (sand, silt, clay, loam, peat, plus the ribbon & ball test and organic colour guide), Landforms (weathering, erosion, mass movement, slope & aspect), Tests (rock and soil identification techniques, slope gradient pacing), and Impact (soil degradation and management strategies)."
            ),
            FAQItem(
                question: "What's the ribbon and ball test?",
                answer: "A hands-on way to estimate soil texture in the field: moisten a small handful of soil, squeeze it into a ball, then try to push it out flat into a ribbon between your thumb and finger. If it falls apart, it's sandy. A short ribbon under 2cm suggests loam. A long, shiny ribbon over 5cm suggests clay. Full details are under Soils and again under Tests."
            )
        ]
    ),
    FAQSection(
        title: "Weather",
        iconName: "cloud.sun.fill",
        items: [
            FAQItem(
                question: "Where does the weather data come from?",
                answer: "Live conditions are pulled from Open-Meteo, a free public weather service — no account or API key needed. Location search uses OpenStreetMap's geocoding service to find coordinates from a place name."
            ),
            FAQItem(
                question: "What's the fieldwork suitability check?",
                answer: "A quick at-a-glance read on whether current conditions are workable for outdoor fieldwork, based on factors like wind, precipitation, and temperature. It's a guide, not a substitute for your own judgement or your school/site's safety guidance."
            ),
            FAQItem(
                question: "Can I log my own weather observations?",
                answer: "Yes — the On-day obs section lets you record what you're actually seeing on site (cloud cover, wind, precipitation, etc.), separately from the live forecast data."
            )
        ]
    ),
    FAQSection(
        title: "Map & Compass",
        iconName: "map.fill",
        items: [
            FAQItem(
                question: "How do I switch between Map and Compass?",
                answer: "Use the segmented control at the top of the Map tab. Map shows the interactive GIS view; Compass shows a full-screen heading, GPS coordinates, and elevation reading."
            ),
            FAQItem(
                question: "What can I do on the map?",
                answer: "Pan and zoom like any map app, switch to a topographic overlay to see contour lines, drop pins to mark sites, and start GPS tracking to record a path as you walk it. Tracking only runs while the app is open and in the foreground."
            ),
            FAQItem(
                question: "Can I link a map pin to a site in my Report?",
                answer: "Yes — from a Site Field Sheet in the Report tab, use the toolbar menu to either drop a pin for that site or jump straight to its location on the map."
            ),
            FAQItem(
                question: "Why does the app need my location?",
                answer: "Location access powers your position on the map, GPS track recording, and the compass's coordinates and elevation reading. It's only used while you're actively using the app — never in the background."
            )
        ]
    ),
    FAQSection(
        title: "Report & exporting to PDF",
        iconName: "doc.plaintext.fill",
        items: [
            FAQItem(
                question: "What's the difference between Field Sheet, Survey Forms, and Report Outline?",
                answer: "They're three sub-sections inside the Report tab, switchable from the bar at the top. Field Sheet is where you record structured data per site (observations, photos, soil colour). Survey Forms are free-form questionnaire-style sheets. Report Outline is a guided space for writing up your findings afterwards."
            ),
            FAQItem(
                question: "How do I export my data to PDF?",
                answer: "Open the Field Sheet for the trip you want, then tap the ••• menu in the top-right corner and choose \"Export / Share\". You can export just the current site, or the whole trip including every site you've recorded. The same ••• menu pattern is used for Survey Forms and the Report Outline — look for the export or share icon in each one's toolbar."
            ),
            FAQItem(
                question: "Where do exported PDFs go?",
                answer: "Exporting opens the standard iOS share sheet — from there you can save to Files, send via email or messages, or send it to apps like Google Drive or AirDrop, just like sharing a photo."
            ),
            FAQItem(
                question: "Can I export as something other than PDF?",
                answer: "PDF is the supported export format for field sheets, survey forms, and report outlines — it's the most reliable format for printing or submitting as a school/university assignment, and keeps your formatting and any photos intact."
            ),
            FAQItem(
                question: "What's the Munsell soil colour picker and how do I use it?",
                answer: "Inside a site's Field Sheet, under the soil colour section, you can match a soil sample against real Munsell soil colour chart swatches by hue family. Tap a swatch to confirm the match — it gets recorded against that site automatically."
            ),
            FAQItem(
                question: "Can I add my own notes to a checklist section?",
                answer: "Yes — every section in the Field Sheet has an \"Add Comment\" option for typing in anything not covered by the structured fields."
            )
        ]
    )
]
