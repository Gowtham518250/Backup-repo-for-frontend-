from pathlib import Path

file_path = "page_transition.dart"

content = Path(file_path).read_text(encoding="utf-8")

content = content.replace(
    "static Widget slideTransition(Widget child)",
    "static Route slideTransition(Widget child)"
)

content = content.replace(
    "static Widget fadeTransition(Widget child)",
    "static Route fadeTransition(Widget child)"
)

content = content.replace(
    "static Widget scaleTransition(Widget child)",
    "static Route scaleTransition(Widget child)"
)

content = content.replace(
    "static Widget bottomSheetTransition(Widget child)",
    "static Route bottomSheetTransition(Widget child)"
)

Path(file_path).write_text(content, encoding="utf-8")

print("✅ Fixed page_transition.dart")