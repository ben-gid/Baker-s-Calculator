import 'package:dough_calculator/repositories/data_to_calculate.dart';
import 'package:dough_calculator/widgets/calculate_button.dart';
import 'package:dough_calculator/widgets/quick_advanced_dough_page.dart';
import 'package:dough_calculator/widgets/quick_dough_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class QuickCalculatePage extends ConsumerStatefulWidget {
  const QuickCalculatePage({super.key});

  @override
  ConsumerState<QuickCalculatePage> createState() => _QuickCalculatePageState();
}

class _QuickCalculatePageState extends ConsumerState<QuickCalculatePage>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();

  // to scroll to top of page
  final _scrollController = ScrollController();

  /// scrolls to top of page
  void _scrollToTop() {
    _scrollController.animateTo(
      0.0,
      duration: Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  var formIndex = 0;

  late final Widget _quickDoughPage = QuickDoughPage(
    key: PageStorageKey('dough'),
  );
  late final Widget _quickAdvancedDoughPage = QuickAdvancedDoughPage(
    key: PageStorageKey('advanced'),
  );

  late final Widget _advancedButton = TextButton(
    onPressed: onAdvancedPressed,
    child: Text("Advanced"),
  );

  late final Widget _backButton = TextButton(
    onPressed: onBackPressed,
    child: Icon(Icons.arrow_back),
  );


  void onAdvancedPressed() => setState(() {
    // validate form on widget change
    final form = _formKey.currentState!;
    if (form.validate()) {
      formIndex = 1;
      _scrollToTop();
    }
  });

  void onBackPressed() => setState(() {
    // validate form on widget change
    final form = _formKey.currentState!;
    if (form.validate()) {
      formIndex = 0;
      _scrollToTop();
    }
  });

  @override
  Widget build(BuildContext context) {
    final Widget calculateButton = CalculateButton(
      formKey: _formKey,
      doughInput: CalculateData.doughInput,
      flourDispersionInput: CalculateData.flourDispersionInput,
      enrichedInput: CalculateData.enrichedInput,
      mixinInput: CalculateData.mixinInput,
    );
    return Scaffold(
      appBar: AppBar(title: Text("Dough Calculator")),
      body: SafeArea(
        child: SingleChildScrollView(
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Column(
            children: [
              Form(
                key: _formKey,
                child: IndexedStack(
                  index: formIndex,
                  children: [
                    Column(
                      children: [
                        _quickDoughPage,
                        Card(
                          margin: const EdgeInsets.symmetric(vertical: 12),
                          child: Row(
                            children: [
                              Expanded(flex:2, child: _advancedButton), 
                              Expanded(flex:3, child: calculateButton),
                            ],
                          ),
                        ),
                      ],
                    ),
                    Column(
                      children: [
                        _quickAdvancedDoughPage, 
                        Card(
                          margin: const EdgeInsets.symmetric(vertical: 12),
                          child: Row(
                            children: [
                              Expanded(flex:2, child: _backButton), 
                              Expanded(flex:3, child: calculateButton),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
