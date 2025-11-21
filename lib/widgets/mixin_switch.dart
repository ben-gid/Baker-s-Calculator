import 'package:dough_calculator/models/field_models.dart';
import 'package:dough_calculator/utils/constants.dart';
import 'package:dough_calculator/widgets/builders/build_section.dart';
import 'package:dough_calculator/widgets/builders/quick_form_text_field.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class MixinSwitch extends StatefulWidget {
  final void Function(Field field) onSaved;

  const MixinSwitch({
    super.key,
    required this.onSaved,
  });

  @override
  State<StatefulWidget> createState() => MixinSwitchState();
}

class MixinSwitchState extends State<MixinSwitch> {
  var isToggled = false;
  var mixinCount = 1;
  
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        buildSection(
          title: mixinTitle,
          titleWidget: CupertinoSwitch(
            activeTrackColor: Theme.of(context).colorScheme.primary,
            value: isToggled, 
            onChanged: (bool newValue) {
              setState(() {
                isToggled = !isToggled;
              });
            },
          ),
          children: [
            if (isToggled)
              Column(
                children: [
                  Padding(
                    padding: const EdgeInsetsGeometry.fromLTRB(0, 0, 0, 10),
                    child: SizedBox(
                      width: double.infinity,
                      child: CupertinoSlidingSegmentedControl<int>(
                        children: _selectorSegments,
                        groupValue: mixinCount,
                        thumbColor: Theme.of(context).colorScheme.primary,
                        onValueChanged: (value) {
                          if (value == null) return;
                          setState(() {
                            mixinCount = value;
                          });
                        },
                      ),
                    ),
                  ),
                  
                  ...List<Widget>.generate(mixinCount, (index) {
                    final label = "Mixin ${index + 1}(%)";
                    final field = Field(label: label, valueType: valuePercent);
                    return QuickFormTextField(
                      field: field, 
                      onSaved: widget.onSaved
                    );
                    
                  }),
                ],
              ),

          ]
        ),
      ],
    );
  }
}

const Map<int, Widget> _selectorSegments = {
  1: Text("1"),
  2: Text("2"),
  3: Text("3"),
  4: Text("4"),
  5: Text("5"),
};
