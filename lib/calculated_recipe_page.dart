import "package:dough_calculator/repositories/data_to_calculate.dart";
import "package:dough_calculator/models/field_models.dart";
import "package:dough_calculator/utils/constants.dart";
import "package:dough_calculator/widgets/builders/build_section.dart";
import 'package:flutter/material.dart';

class CalculatedRecipePage extends StatelessWidget {

  const CalculatedRecipePage({super.key});

  Widget _buildOutputRecipe(BuildContext context) {
    final args = ModalRoute.of(context)!.settings.arguments as Map;

    final List<OutputFieldGroup> calculatedOutputFields = args["calculatedOutputFields"];
    final Map<String, double> calculatedFlourDispersion = args["calculatedFlourDispersion"];
    final List<Field> flourDispersionInput = args["flourDispersionInput"];

    return Column(
      children: [
        ...calculatedOutputFields.map((group) {
          return buildSection(
            title: group.name, 
            children: [
              ...group.values.entries.map((entry) {
                if (flourDispersionInput.isNotEmpty && group.name == "Dough" && entry.key == "Flour") {
                  return Column(
                    children: [
                      ... calculatedFlourDispersion.entries.map((entry) {
                        String? flourDispersionPercentage = getField(entry.key, flourDispersionInput)?.label;
                        return Column(
                          children: [
                            Padding(
                              padding: EdgeInsets.symmetric(vertical: 2, horizontal: 1),
                              child: ListTile(
                                title: Text(
                                  "${entry.key} ($flourDispersionPercentage%):",
                                  style: TextStyle(
                                    
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: Text(
                                  "${entry.value.toStringAsFixed(2)}g",
                                  style: TextStyle(
                                    fontSize: 20,
                                  ),
                                )
                              )
                            ),
                          ],
                        );
                      }),
                    ],
                  );
                } 
                      
                String value;
                if (entry.key != eggOutputLabel) {
                  value = "${entry.value?.toStringAsFixed(2)}g";
                } else {
                  value = entry.value!.toStringAsFixed(0);
                }
                return Padding(
                  padding: EdgeInsets.symmetric(vertical: 2, horizontal: 1),
                  child: ListTile(
                    title: Text(
                      "${entry.key}:",
                      style: TextStyle(
                        
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(
                      value,
                      style: TextStyle(
                        fontSize: 20,
                      ),
                    )
                  )
                ); 
              }),
            ]
          );
        }),
      ],
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () {
            // clear all data when user goes back to remove old values
            CalculateData.clearAll();
            Navigator.pop(context);
          },
      ),
        title: Text("Calculated Recipe"),
      ),
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              child: Column(
                children: [
                  _buildOutputRecipe(context),
                  SizedBox(height: 60,)
                ],
              ),
            ),
          ]
        ),
      ),
    );
  }
} 