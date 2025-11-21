import 'package:flutter/material.dart';

Scaffold buildPage({
  required final GlobalKey<FormState> formKey,
  required final ScrollController scrollController,
  required final List<Widget> formChildren,
  required final String appBarTitle,
  required void Function() onAppBarBackPressed,
  Widget? positionedButton,
}) {

  return Scaffold(
    appBar: AppBar(
      title: Text(appBarTitle),
      leading: IconButton(
        icon: Icon(Icons.arrow_back),
        onPressed: () { onAppBarBackPressed(); },
      ),
    ),
    body: SafeArea(
      child: Stack(
        children: [
          SingleChildScrollView(
            controller: scrollController,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Form(
                  key: formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ...formChildren,
                      SizedBox(height: 60,),
                    ],
                  ),
                ),
              ],
            )
          ),
          
          if (positionedButton != null)
            Positioned(
              bottom: 16,
              right: 16,
              left: 16,
              child: positionedButton
            ),
        ]
      ),
    ),
  );
    
}