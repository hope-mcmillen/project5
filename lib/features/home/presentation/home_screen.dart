import 'package:flutter/material.dart';

import '../../../ui/theme/app_theme.dart';

enum AppSection {
  home(
    'Home',
    Icons.home_outlined,
    'Welcome to ResuRhombus',
    'Your next opportunity starts here. Use the menu to explore your workspace.',
  ),
  account(
    'Account',
    Icons.person_outline,
    'Your account',
    'Your profile and account settings will be available here.',
  ),
  documents(
    'Documents',
    Icons.description_outlined,
    'Your documents',
    'This will be the place to upload and manage your resumes and documents.',
  ),
  jobs(
    'Job Listings',
    Icons.work_outline,
    'Find your next opportunity',
    'Browse job listings here once they become available.',
  );

  const AppSection(this.label, this.icon, this.heading, this.description);
  final String label;
  final IconData icon;
  final String heading;
  final String description;
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  AppSection _section = AppSection.home;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('ResuRhombus')),
      drawer: Drawer(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(AppStyle.medium),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppStyle.large),
                child: Row(
                  children: [
                    const Icon(Icons.diamond_outlined),
                    const SizedBox(width: AppStyle.small),
                    Expanded(
                      child: Text('ResuRhombus', style: text.titleLarge),
                    ),
                    IconButton(
                      tooltip: 'Close menu',
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              const Divider(),
              const SizedBox(height: AppStyle.medium),
              for (final section in AppSection.values)
                ListTile(
                  leading: Icon(section.icon),
                  title: Text(section.label),
                  selected: _section == section,
                  shape: const RoundedRectangleBorder(
                    borderRadius: AppStyle.radius,
                  ),
                  onTap: () {
                    setState(() => _section = section);
                    Navigator.pop(context);
                  },
                ),
            ],
          ),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: AppStyle.contentWidth),
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.all(AppStyle.large),
              children: [
                Text(_section.label, style: text.labelLarge),
                const SizedBox(height: AppStyle.medium),
                Text(_section.heading, style: text.headlineMedium),
                const SizedBox(height: AppStyle.medium),
                Text(_section.description, style: text.bodyLarge),
                const SizedBox(height: AppStyle.extraLarge),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppStyle.large),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(_section.icon, size: AppStyle.extraLarge),
                        const SizedBox(height: AppStyle.medium),
                        Text(
                          _section == AppSection.home
                              ? 'Your workspace'
                              : 'Coming soon',
                          style: text.titleLarge,
                        ),
                        const SizedBox(height: AppStyle.small),
                        Text(
                          _section == AppSection.home
                              ? 'Account, documents, and job listings, all in one place.'
                              : 'This section is ready for future features.',
                          style: text.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
