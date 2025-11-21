import 'package:flutter/material.dart';

Widget buildSection({
  String? title, 
  Widget? titleWidget, 
  required List<Widget> children,
}) {
  late final MainAxisAlignment mainAxisAlignment;
  if (titleWidget == null) {
     mainAxisAlignment = MainAxisAlignment.start;
  } else {
     mainAxisAlignment = MainAxisAlignment.spaceBetween;
  }
  
  return Card(
    elevation: 2,
    margin: const EdgeInsets.symmetric(vertical: 12),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [ 
          Row(
            mainAxisAlignment: mainAxisAlignment,
            children: [
              if (title != null)
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18, 
                    fontWeight: FontWeight.bold
                  )
                ),
              if (titleWidget != null)
                 titleWidget,
            ]
          ),
          const SizedBox(height: 12),
          ...children,
        ],
        
      ),
    ),
  );
}