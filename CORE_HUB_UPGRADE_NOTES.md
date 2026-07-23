# FieldWise Core Hub Upgrade — Stage 1

## Included
- Agriculture-style searchable card catalogue on the Core Home tab.
- Category chips and adaptive iPhone/iPad card grid.
- Role-aware wording for teachers and students.
- Direct launch cards for FieldWise Geography, History and Agriculture.
- Connected Apps test screen.
- Sync Centre screen.
- Updated bottom navigation labels: Home, Activities, Fieldwork, Map, Portfolio.
- Core Info.plist query schemes for the three student apps.

## Student-app URL schemes expected
- Geography: `fieldwisegeography://home`
- History: `fieldwisehistory://home`
- Agriculture: `fieldwiseagriculture://home`

Geography already registers its scheme in the supplied project. History and Agriculture still need their URL schemes registered in their targets before their Core launch cards can open them on-device.

## Next integration stage
The next stage should pass `activityID`, `classID`, `studentID`, and a return URL into each app, then add an `onOpenURL` router in each student app so Core can open the exact assigned activity rather than only the app home screen.
