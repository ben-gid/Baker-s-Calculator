import 'package:dough_calculator/utils/constants.dart';
import 'package:dough_calculator/models/field_models.dart';


final List<FieldGroup> yeastInputFields = [
  FieldGroup(
    groupName: "Dough", 
    fields: [
      Field(
        label: flourLabel, 
        valueType: valueGram,
        helperText: "typically 400g - 600g per loaf"
      ),
      Field(
        label: hydrationLabel,
        valueType: valuePercent, 
        helperText: "the water(or other liquid) content relative to total flour"
      ),
      Field(
        label: saltLabel, 
        valueType: valuePercent,
        helperText: "salt relative to total flour(typically between 1.8% to 2.2%)"
      ),
      Field(
        label: yeastLabel,
        valueType: valuePercent, 
        helperText: "the yeast amount relative to total flour (instant yeast: typically between 1% to 2%)"
      ),
    ]
  )
];


final List<FieldGroup> sourdoughInputFields = [
  FieldGroup(groupName: "Dough", fields: [
    Field(
      label: doughLabel, 
      valueType: valueGram,
      helperText: "final weight of all ingredients combined(typically 700g - 1kg per loaf)"
    ),
    Field(
      label: hydrationLabel, 
      valueType: valuePercent,
      helperText: "the water content relative to total flour"
    ),
    Field(
      label: saltLabel, 
      valueType: valuePercent,
      helperText: "salt relative to total flour(typically between 1.8% to 2.2%)"
    ),
  ]),
  FieldGroup(groupName: "Levain", fields: [
    Field(
      label: levainLabel, 
      valueType: valuePercent,
      helperText: "the levain amount relative to total flour(typically 20%)"
    ),
    Field(
      label: levainHydrationLabel, 
      valueType: valuePercent,
      helperText: "water percent in the levain (typically 100%)"
    ),
  ]),
];

final List<FieldGroup> prefermentInputFields = [
  FieldGroup(groupName: "Dough", fields: [
    Field(
      label: doughLabel, 
      valueType: valueGram,
      helperText: "final weight of all ingredients combined(typically 700g - 1kg per loaf)"
    ),
    Field(
      label: hydrationLabel, 
      valueType: valuePercent,
      helperText: "the water content relative to total flour"
    ),
    Field(
      label: saltLabel, 
      valueType: valuePercent,
      helperText: "salt relative to total flour(typically between 1.8% to 2.2%)"
    ),
  ]),
  FieldGroup(groupName: "Preferment", fields: [
    Field(
      label: prefermentPercentlabel, 
      valueType: valuePercent,
      helperText: "the preferment amount relative to flour in dough"
    ),
    Field(
      label: prefermentHydrationLabel, 
      valueType: valuePercent,
      helperText: "water (or other liquid) relative to the flour in the preferment"
    ),
    Field(
      label: prefermentYeastLabel,
      valueType: valuePercent,
      helperText: "yeast relative to the flour in the preferment "
    ),
  ]),
];

final FieldGroup enrichmentInputFields = FieldGroup(
  groupName: "Enrich Dough", 
  fields: [
    Field(
      label: fatLabel,
      valueType: valuePercent,
      helperText: "fat as percentage (oil, butter, etc...) relative to total flour",
    ),
    Field(
      label: sugarLabel,
      valueType: valuePercent,
      helperText: "sugar as percentage(cane sugar, honey, etc...) relative to total flour",
    ),
    Field(
      label: eggLabel,
      valueType: valueCount,
      helperText: "number of 'large' egg(s) in recipe",
    ),
  ]
);