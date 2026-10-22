# Baker's Calculator (Dough Calculator)

A comprehensive, production-ready Flutter application tailored for professional bakers and baking enthusiasts. It provides robust tools to calculate precise ingredient weights, manage complex recipes, and scale batches dynamically, with seamless REST API cloud synchronization.

## Project Architecture & Tech Stack

This project is structured for scalability and maintainability, adhering to clean architecture principles:

- **Framework:** Flutter (target SDK: `^3.9.2`)
- **State Management:** Riverpod (`flutter_riverpod`) for reactive state, authentication, and calculation pipelines; `provider` for legacy or simplified dependencies.
- **Cloud/Sync:** Custom FastAPI backend integration utilizing JWT Authentication and `SharedPreferences` for secure, siloed recipe syncing.
- **Code Quality:** Enforced via `flutter_lints` and unit testing (`flutter_test`).

### Directory Structure (`lib/`)
- **`data/`**: Static data definitions and pre-populated default recipes (e.g., Sourdough, Pizza, Challah).
- **`models/`**: Strongly typed data classes (`Recipe`, `Field`, etc.) with JSON serialization capabilities.
- **`notifiers_and_providers/`**: Global state containers and Riverpod providers (e.g., `auth_provider.dart`) governing calculation inputs, active recipe states, API integration logic, and UI reactivity.
- **`repositories/`**: Abstractions for local data persistence and calculation state handling.
- **`utils/`**: Core mathematical engines (e.g., `quick_calculate_recipe.dart`), app-wide constants, and helpers.
- **`widgets/`**: Reusable component architecture:
    - `builders/`: Form and interactive element factories.
    - specialized domains: Enriched Dough, Flour Dispersion, Mixins.
- **Pages**: Top-level route destinations including robust authentication loops:
    - `login_page.dart` & `register_page.dart`: Client-validated credential endpoints.
    - `account_page.dart`: Logged-in user overview routing.
    - `quick_calculate_page.dart`, `recipe_form_page.dart`, `recipes_page.dart`.

## Technical Features (Developer's Standpoint)

### 1. Advanced Core Calculation Engine
Located in `utils/quick_calculate_recipe.dart`, the math engine is highly modular and supports complex hydration mathematics:
- **Dough Variations:** Dedicated pipelines for standard **Yeast Dough**, **Sourdough** (levain calculations), and **Preferments** (poolish/biga).
- **Dual Calculation Modes:** 
  - *Dough Weight Mode:* Calculates required total flour dynamically based on target final total weight, optionally accounting for static enrichments (e.g., egg weights mapped to constants like 50g) and mixins.
  - *Flour Weight Mode:* Traditional baker's percentage calculation propagating from a fixed flour weight.
- **Composition Analysis:** Supports breaking down components into Enriched inputs (Fats, Sugars, Eggs), Flour Dispersion, and Mixins. Sourdough math properly handles levain hydration extraction from the main dough formula.

### 2. Custom REST API Sync & Authentication
The app connects securely to a private FastAPI backend using standard OAuth2 architecture. Upon client-side validated registration or login, the payload receives a JWT encoded token which is persisted via `SharedPreferences`. The app's `authProvider` forces a redirect to the authentication screen natively before exposing HTTP-bound pages for recipe synchronization.

### 3. Dynamic UI & Form Building
- **Recipe Management:** Employs a split system accommodating immutable "Base Recipes" and mutable "My Recipes". 
- **Dynamic Scaling System:** Stateful scaling mechanisms allow continuous recalculations via presets (0.5x, 2x) or arbitrary multipliers without losing baseline percentages.
- **Weight / % Toggle:** The UI seamlessly toggles representations between strictly relative values (Baker's %) and absolute computed weights (grams).
- **Theming:** Centralized in `themes.dart`, featuring a premium UI with a dark mode implementation, dynamic color matching, and optimized layout trees to prevent overflow bottlenecks.

## Getting Started

1.  **Dependencies**: Run `flutter pub get`.
2.  **Ensure Connectivity**: If developing dynamically over a local host loopback interface, make sure to execute `adb reverse tcp:8000 tcp:8000` to bind your emulator's ports exactly to the backend environment variables securely.
3.  **Run**: Execute `flutter run` on your preferred device or emulator.
4.  **Analyze & Test**: Run `flutter analyze` to verify code quality.

---
For additional help with Flutter, refer to the [online documentation](https://docs.flutter.dev/).
