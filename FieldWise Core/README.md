# FieldWise Geography — Geography Fieldwork Companion

A native SwiftUI iOS/iPadOS app for student geography fieldwork. Targets **iOS 16+** and runs in iPad desktop-class / Mac Catalyst-style regular-width layouts as well as standard iPhone.

---

## Project Structure

```
FieldWise Geography/
├── FieldWise Geography/
│   ├── App/
│   │   ├── FieldWiseGeographyApp.swift         ← @main entry point
│   │   ├── ContentView.swift                  ← Root 5-tab TabView (Plan / Landscapes / Weather / Map / Report)
│   │   └── Info.plist                         ← Permissions, ATS exceptions, orientations
│   │
│   ├── Models/
│   │   ├── PlanModel.swift                    ← Fieldwork plan data + PlanStore
│   │   ├── GeologyModel.swift                 ← Rock/soil types, landform processes, human-impact data
│   │   ├── WeatherModel.swift                 ← Weather API models + FieldObservation
│   │   ├── ChecklistModel.swift               ← Master pre/on-site/post checklist items
│   │   ├── FieldChecklistModels.swift         ← FieldTrip + persistence-layer models for Survey Forms/Report Outline
│   │   ├── FieldSurveyFormModels.swift        ← Free-form survey/questionnaire sheet data
│   │   ├── FieldReportOutlineModels.swift     ← Guided write-up / report outline data
│   │   ├── SiteFieldSheetModel.swift          ← Per-site observation catalog (rock/soil/vegetation terms) + site sheet checklist
│   │   ├── FieldPhotoCapture.swift            ← Photo capture/attachment model used across field sheets
│   │   ├── GISMapModel.swift                  ← MapKit overlay annotations + OpenTopoMap tile overlay
│   │   ├── MunsellSoilColorModel.swift        ← Munsell chart catalog + picker selection model
│   │   ├── MunsellSwatchData.swift            ← Real swatch data for all 12 Munsell Soil Color Charts
│   │   └── HelpFAQModel.swift                 ← In-app Help/FAQ content
│   │
│   ├── Views/
│   │   ├── Plan/
│   │   │   └── PlanViews.swift                ← Multi-step plan wizard + readiness summary
│   │   ├── Geology/
│   │   │   └── GeologyViews.swift             ← Landscapes tab: Rocks · Soils · Landforms · Field tests · Human impact
│   │   ├── Weather/
│   │   │   └── WeatherViews.swift             ← Weather, MapKit, on-day observations
│   │   ├── Onboarding/
│   │   │   ├── WelcomeView.swift              ← First-launch welcome flow
│   │   │   └── HelpFAQView.swift              ← In-app help
│   │   ├── Checklist/                         ← Root for the Report tab's 3 sub-sections
│   │   │   ├── FieldChecklistView.swift       ← Segmented switcher: Field Sheet / Survey Forms / Report Outline
│   │   │   ├── SiteFieldSheetView.swift       ← Interactive per-site field data sheet (the main "Checklist" replacement)
│   │   │   ├── SiteFieldSheetExporter.swift   ← Site Field Sheet → PDF export
│   │   │   ├── MunsellSoilColorPickerView.swift ← Nested chart picker for recording soil colour
│   │   │   └── FieldReportOutlineView.swift   ← Guided report write-up view
│   │   └── FieldSurveyFormView.swift          ← Free-form survey/questionnaire forms
│   │
│   ├── Services/
│   │   ├── WeatherService.swift               ← Open-Meteo + Nominatim geocoding
│   │   ├── GISMapStore.swift                  ← Map state, pins, topo overlay toggle
│   │   ├── SiteFieldSheetStore.swift          ← Site Field Sheet persistence + active trip/site state
│   │   ├── FieldChecklistStore.swift          ← Trip list + Survey Forms/Report Outline persistence
│   │   ├── FieldChecklistStore+SurveyAndReport.swift ← Survey Forms/Report Outline mutation helpers
│   │   ├── FieldChecklistExport.swift         ← FieldTrip checklist → CSV + PDF export, share sheet wrapper
│   │   ├── FieldReportExporter.swift          ← Report Outline → PDF export
│   │   ├── FieldSurveyExporter.swift          ← Survey Forms → PDF export
│   │   └── FieldPDFKit.swift                  ← Shared low-level PDF drawing flow used by all exporters
│   │
│   ├── Components/
│   │   └── GeoComponents.swift                ← Shared UI components (cards, badges, flow layout, field labels)
│   │
│   ├── Assets.xcassets/                       ← App icon, accent color, named Geo* colour sets
│   │
│   └── README.md
│
├── FieldWise GeographyTests/
├── FieldWise GeographyUITests/
└── FieldWise Geography.xcodeproj
```

---

## App structure: 5 main tabs

The app opens to a 5-tab `TabView` (`ContentView.swift`). On iPhone this renders as the standard bottom tab bar; on iPad / Mac / iPad desktop-class layouts, SwiftUI floats it as a bar across the **top** of the screen instead — several internal views account for this (see "iPad / regular-width layout" below).

1. **Plan** — fieldwork planning wizard
2. **Landscapes** — geology, soils, landforms, and human-impact reference content
3. **Weather** — live forecast, suitability assessment, on-day observations
4. **Map** — GIS map with topo overlay and pin drop
5. **Report** — the data-recording and write-up workspace, itself split into 3 sub-sections via an internal segmented picker (not a nested `TabView` — see note in `FieldChecklistView.swift`):
   - **Field Sheet** — the interactive per-site Site Field Sheet
   - **Survey Forms** — free-form questionnaire-style sheets
   - **Report Outline** — guided space for writing up findings afterwards

---

## Setup in Xcode

### 1. Open the project

Open `FieldWise Geography.xcodeproj` directly in Xcode — this is an existing Xcode project, not a loose source folder, so there's no need to create a new project or manually drag files in.

### 2. Confirm named colours exist

`Assets.xcassets` should already contain the following Color Sets, each with Light/Dark appearances:

| Name          |
|---------------|
| GeoGreen      |
| GeoGreenDark  |
| GeoGreenMid   |
| GeoAmber      |
| GeoAmberDark  |
| GeoCoral      |
| GeoBlue       |
| GeoSurface    |
| GeoGray       |

If any are missing (e.g. after a merge), add them via **File > New > Color Set** and match the existing hex values from a sibling color set.

### 3. Capabilities & permissions

Already configured in `Info.plist` and `project.json`:
- **Maps** capability (MapKit + Core Location)
- `NSLocationWhenInUseUsageDescription` — map position
- `NSCameraUsageDescription` — photographing rock/soil/site features
- `NSPhotoLibraryUsageDescription` — adding existing photos to field sheets
- ATS exceptions for `api.open-meteo.com`, `nominatim.openstreetmap.org`, and `tile.opentopomap.org`

### 4. Build & run

Select a simulator or device (iPhone or iPad) → **Cmd+R**.

---

## Features

### Plan tab
- Multi-step fieldwork planning wizard
- Aims, location, date, sampling strategy
- Equipment checklist (chip toggles, categorised)
- Data collection methods grid
- Risk assessment (weather, terrain, traffic, water)
- Safety & ethics commitments
- Recording formats + anomaly log
- Pre-departure checklist
- Auto-generated readiness summary

### Landscapes tab
Five sub-tabs via an internal segmented picker:
- **Rocks** — igneous, sedimentary, metamorphic cards (formation, hardness, examples, fieldwork clues)
- **Soils** — soil type cards with drainage/nutrient ratings, ribbon & ball test, organic content by colour
- **Landforms** — weathering, erosion, and mass movement processes; slope/aspect reference
- **Field tests** — rock and soil identification tests, including ribbon/ball test and slope gradient pace method
- **Human impact** — soil degradation issues and management strategy groups for coastal/riverine/agricultural contexts

### Weather tab
- Live weather via **Open-Meteo API** (free, no key required)
- Geocoding via **Nominatim / OpenStreetMap** (free, no key required)
- Current temperature, feels-like, wind, humidity, visibility
- Fieldwork suitability assessment (Good / Caution / Unsafe)
- Multi-day forecast strip
- **MapKit** map with standard / satellite / hybrid toggle
- Geocoded location pin drop
- On-day field observations recorder with auto-fill

### Map tab
- Native **MapKit** map
- Custom **OpenTopoMap** contour-line tile overlay (OSM + SRTM data) toggle, layered over MapKit
- Pin drop and GIS annotation state via `GISMapStore`

### Report tab
Three sub-sections, switched via a segmented picker (see "App structure" above):

**Field Sheet** — the main data-recording surface
- Per-site observation catalog: rock type, rock characteristics, soil type, soil characteristics, vegetation
- **Munsell Soil Color picker** — nested chart picker covering all 12 official Munsell Soil Color Charts (10R, 2.5YR, 5YR, 7.5YR, 10YR, 2.5Y, 5R, 7.5R, 5Y, the 10Y–5GY "Olive Greens" chart, and both Gley charts), plus a curated Common Australian Soil Colours quick-reference list
- Site overview / sample / human-impact photo checklist with photo capture and library import
- Site Field Sheet → PDF export

**Survey Forms** — free-form questionnaire-style sheets, exportable to PDF

**Report Outline** — guided write-up space for findings, exportable to PDF

### Onboarding & Help
- First-launch **Welcome** flow
- In-app **Help/FAQ**, including guidance on the difference between Field Sheet, Survey Forms, and Report Outline, and how to export/share each

---

## iPad / regular-width layout

SwiftUI renders the main `TabView`'s 5 tabs as a bar floating across the **top** of the screen on iPad and other regular-width layouts (rather than pinned to the bottom as on iPhone). Most internal sub-navigation pickers (Weather, Landscapes) sit inside their own `NavigationStack`, which naturally reserves clearance below that floating bar.

The Report tab's segmented picker (`FieldChecklistView.swift`) has no `NavigationStack` of its own above it — deliberately, since one of its sub-sections (Field Sheet) already wraps itself in one, and nesting another would produce a broken double tab bar. Instead its top padding is `horizontalSizeClass`-aware: standard padding on iPhone (compact width), extra clearance on iPad/Mac (regular width) so the picker doesn't sit under the floating tab bar. If this ever needs retuning, it's the single padding value at the top of `FieldChecklistView.body`.

---

## Data persistence

User data persists via `UserDefaults`, scoped per store:

| Store                    | Contents                                              |
|---------------------------|--------------------------------------------------------|
| `PlanStore`               | Full fieldwork plan                                    |
| `SiteFieldSheetStore`     | Trips, sites, observations, Munsell selections, photos |
| `FieldChecklistStore`     | Trips, Survey Forms, Report Outline content            |
| `GISMapStore`             | Map pins / annotation state                            |
| Weather observation       | On-day `FieldObservation`                               |
| Master checklist          | Checked item IDs                                        |
| `hasSeenWelcome`           | Whether the first-launch Welcome flow has been shown    |

---

## External APIs used

| API                | Purpose                          | Key required? | Cost  |
|---------------------|-----------------------------------|----------------|-------|
| Open-Meteo          | Weather forecasts                 | No             | Free  |
| Nominatim (OSM)     | Location geocoding                | No             | Free  |
| MapKit (Apple)      | Interactive map                   | No             | Free  |
| OpenTopoMap         | Topographic contour tile overlay  | No             | Free  |

All are free, openly licensed, and suitable for student use.

---

## Notes & customisation

- **Colour scheme**: all colours are named assets in `Assets.xcassets` — change them in one place.
- **Adding equipment / data methods**: edit the relevant arrays in `PlanModel.swift`.
- **Adding rock/soil/landform/human-impact content**: edit the arrays in `GeologyModel.swift`.
- **Adding observation terms (rock/soil/vegetation)**: edit `GeoObservationCatalog` in `SiteFieldSheetModel.swift`.
- **Adding Munsell chart data**: edit `MunsellSwatchData.swift` (real swatch arrays) and wire new charts into `MunsellSoilColorCatalog.allCharts` in `MunsellSoilColorModel.swift`.
- **Adding checklist items**: edit `masterChecklist` in `ChecklistModel.swift`.
- **Adding Help/FAQ entries**: edit `HelpFAQModel.swift`.

---

## Requirements

- Xcode 15+
- iOS 16.0 deployment target
- Swift 5.9+
- Internet connection (for weather, geocoding, and map tiles)
