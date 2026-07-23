# FieldWise Core Integration — Stage 2

Implemented in this package:

- Core launches Geography, History and Agriculture with activityID, classID, studentID, taskID, activityTitle and returnToCore.
- All three student apps register their URL schemes.
- All three student apps parse Core activity deep links.
- A visible Core assignment banner appears in the destination app.
- The destination app switches to its Activity/Investigate tab.
- Return to Core sends the source app and activity context back to Core.
- Core confirms the returned activity through its own fieldwisecore:// URL handler.

Test links:

- fieldwisegeography://activity/test-activity?classID=test-class&studentID=test-student&taskID=task-1&activityTitle=Geography%20Test&returnToCore=true
- fieldwisehistory://activity/test-activity?classID=test-class&studentID=test-student&taskID=task-1&activityTitle=History%20Test&returnToCore=true
- fieldwiseagriculture://activity/test-activity?classID=test-class&studentID=test-student&taskID=task-1&activityTitle=Agriculture%20Test&returnToCore=true
