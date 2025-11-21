import "package:dough_calculator/calculated_recipe_page.dart";
import "package:dough_calculator/quick_calculate_page.dart";
import "package:dough_calculator/themes.dart";
import 'package:flutter/material.dart';


class DoughCalculator extends StatelessWidget {
  const DoughCalculator({super.key});

  @override
  Widget build(BuildContext context) {
    return  MaterialApp( // Root widget
        theme: darkTheme,
        initialRoute: "/",
        routes: {
          "/": (context) => QuickCalculatePage(),
          "/calculatedRecipePage": (context) => CalculatedRecipePage(),

        },
    );
  }
}

