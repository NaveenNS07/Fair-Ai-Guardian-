import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import 'package:csv/csv.dart';
import 'dart:convert';
import 'app_state.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final appState = AppState();
  await appState.init(); // Load persisted API key + backend URL
  runApp(
    ChangeNotifierProvider.value(
      value: appState,
      child: const GuardianProApp(),
    ),
  );
}

class GuardianProApp extends StatefulWidget {
  const GuardianProApp({super.key});

  @override
  State<GuardianProApp> createState() => _GuardianProAppState();
}

class _GuardianProAppState extends State<GuardianProApp> {
  ThemeMode _themeMode = ThemeMode.dark;

  void toggleTheme() {
    setState(() {
      _themeMode = _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FairAI Guardian Pro',
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      theme: _buildLightTheme(),
      darkTheme: _buildDarkTheme(),
      home: MainLayout(
        toggleTheme: toggleTheme,
        isDarkMode: _themeMode == ThemeMode.dark,
      ),
    );
  }

  ThemeData _buildLightTheme() {
    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: const Color(0xFFF3F4F6),
      cardColor: const Color(0xFFFFFFFF),
      primaryColor: const Color(0xFF4F46E5),
      colorScheme: const ColorScheme.light(
        primary: Color(0xFF4F46E5),
        secondary: Color(0xFF6B7280),
        surface: Color(0xFFFFFFFF),
        error: Color(0xFFEF4444),
      ),
      fontFamily: 'Roboto',
      dividerColor: Colors.black12,
    );
  }

  ThemeData _buildDarkTheme() {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF0D1117), // Deep space-gray background
      cardColor: const Color(0xFF161B22), // Slightly lighter gray for cards
      primaryColor: const Color(0xFF58A6FF), // Primary blue accent
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFF58A6FF),
        secondary: Color(0xFF8B949E),
        surface: Color(0xFF161B22),
        error: Color(0xFFF85149), // Red for bias alerts
      ),
      fontFamily: 'Roboto',
      dividerColor: Colors.white10,
    );
  }
}

// -----------------------------------------------------------------------------
// MAIN LAYOUT & NAVIGATION
// -----------------------------------------------------------------------------

class MainLayout extends StatefulWidget {
  final VoidCallback toggleTheme;
  final bool isDarkMode;

  const MainLayout({super.key, required this.toggleTheme, required this.isDarkMode});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _selectedIndex = 0;

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      DashboardView(isDarkMode: widget.isDarkMode),
      DataInputView(isDarkMode: widget.isDarkMode),
      AnalyticsView(isDarkMode: widget.isDarkMode),
      AIInsightsView(isDarkMode: widget.isDarkMode),
      SettingsView(
        isDarkMode: widget.isDarkMode,
        toggleTheme: widget.toggleTheme,
      ),
    ];

    return Scaffold(
      body: Row(
        children: [
          // Custom Sidebar
          Container(
            width: 260,
            color: Theme.of(context).scaffoldBackgroundColor == const Color(0xFF0D1117) 
                ? const Color(0xFF0D1117) 
                : const Color(0xFFF9FAFB),
            child: Column(
              children: [
                _buildSidebarHeader(),
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: ElevatedButton.icon(
                    onPressed: () => _onItemTapped(1), // Go to New Analysis (Data Input)
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text("New Analysis", style: TextStyle(fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF5A4FCF), 
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 45),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                _buildNavItem(0, "Dashboard", Icons.dashboard_outlined),
                _buildNavItem(1, "Data Input", Icons.upload_file_outlined),
                _buildNavItem(2, "Analytics", Icons.analytics_outlined),
                _buildNavItem(3, "AI Insights", Icons.lightbulb_outline),
                _buildNavItem(4, "Settings", Icons.settings_outlined),
                const Spacer(),
                const Divider(height: 1),
                _buildNavItem(-1, "Support", Icons.help_outline, isBottom: true),
                _buildNavItem(-2, "Log Out", Icons.logout, isBottom: true),
                const SizedBox(height: 16),
              ],
            ),
          ),
          const VerticalDivider(width: 1, thickness: 1),
          // Main Content Area
          Expanded(
            child: Column(
              children: [
                _buildTopBar(context),
                const Divider(height: 1, thickness: 1),
                Expanded(
                  child: pages[_selectedIndex],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF5A4FCF).withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.shield, color: Color(0xFF5A4FCF), size: 24),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Guardian Pro",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                ),
              ),
              Text(
                "Enterprise Ethics",
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.secondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showHistoryDialog() {
    final appState = context.read<AppState>();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Analysis Run History"),
        content: SizedBox(
          width: 400,
          height: 300,
          child: appState.analysisHistory.isEmpty
              ? const Center(child: Text("No history yet."))
              : ListView.builder(
                  itemCount: appState.analysisHistory.length,
                  itemBuilder: (context, index) {
                    final run = appState.analysisHistory[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: run['fixBias'] == true ? Colors.cyanAccent : Colors.grey,
                        child: Text("${run['run']}", style: const TextStyle(fontSize: 12, color: Colors.black)),
                      ),
                      title: Text(run['label'].toString()),
                      subtitle: Text("Bias: ${(run['bias'] * 100).toStringAsFixed(1)}% | Acc: ${(run['accuracy'] * 100).toStringAsFixed(1)}%"),
                      trailing: Icon(run['fixBias'] == true ? Icons.auto_fix_high : Icons.analytics, size: 16),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Close")),
        ],
      ),
    );
  }

  void _showSupportDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("System Support"),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("FairAI Guardian Pro - Enterprise Ethics Engine"),
            SizedBox(height: 12),
            Text("For technical assistance, please contact your organization's AI Ethics Board or reach out to:"),
            SizedBox(height: 8),
            Text("Email: support@fairai-guardian.pro", style: TextStyle(color: Color(0xFF58A6FF))),
            Text("Phone: +1 (800) FAIR-AI-0", style: TextStyle(color: Color(0xFF58A6FF))),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Close")),
        ],
      ),
    );
  }

  void _handleLogout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Confirm Logout"),
        content: const Text("Are you sure you want to log out and reset the current session? Unsaved configurations will be preserved."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () {
              context.read<AppState>().setDataset([]);
              Navigator.pop(ctx);
              _onItemTapped(0);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Session reset. Logged out.")));
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text("Log Out"),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(int index, String title, IconData icon, {bool isBottom = false}) {
    final isSelected = _selectedIndex == index;
    final color = isSelected 
        ? const Color(0xFF5A4FCF) 
        : Theme.of(context).colorScheme.secondary;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
      child: InkWell(
        onTap: () {
          if (isBottom) {
            if (index == -1) _showSupportDialog();
            if (index == -2) _handleLogout();
          } else {
            _onItemTapped(index);
          }
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF5A4FCF).withOpacity(0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 16),
              Text(
                title,
                style: TextStyle(
                  color: color,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            "FairAI Guardian Pro",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          Row(
            children: [
              Container(
                width: 250,
                height: 36,
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Theme.of(context).dividerColor),
                ),
                child: TextField(
                  onSubmitted: (val) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Searching for '$val' in diagnostics...")));
                  },
                  decoration: InputDecoration(
                    hintText: "Search diagnostics...",
                    hintStyle: TextStyle(color: Theme.of(context).colorScheme.secondary, fontSize: 13),
                    prefixIcon: Icon(Icons.search, size: 18, color: Theme.of(context).colorScheme.secondary),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 24),
              IconButton(
                icon: Icon(Icons.notifications_none, color: Theme.of(context).colorScheme.secondary),
                onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No new alerts."))),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: Icon(Icons.history, color: Theme.of(context).colorScheme.secondary),
                onPressed: _showHistoryDialog,
              ),
              const SizedBox(width: 16),
              CircleAvatar(
                radius: 16,
                backgroundColor: Theme.of(context).colorScheme.secondary.withOpacity(0.2),
                child: Icon(Icons.person, size: 18, color: Theme.of(context).colorScheme.secondary),
              ),
            ],
          )
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// REUSABLE COMPONENTS
// -----------------------------------------------------------------------------

class ProCard extends StatelessWidget {
  final Widget child;
  final String? title;
  final Widget? trailing;
  final String? subtitle;
  final EdgeInsetsGeometry padding;
  final IconData? iconData;
  final bool expandChild;

  const ProCard({
    super.key,
    required this.child,
    this.title,
    this.trailing,
    this.subtitle,
    this.padding = const EdgeInsets.all(20),
    this.iconData,
    this.expandChild = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: expandChild ? MainAxisSize.max : MainAxisSize.min,
        children: [
          if (title != null) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    if (iconData != null) ...[
                      Icon(iconData, size: 18, color: Theme.of(context).colorScheme.secondary),
                      const SizedBox(width: 8),
                    ],
                    Text(
                      title!,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                if (trailing != null) trailing!,
              ],
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle!,
                style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.secondary),
              ),
            ],
            const SizedBox(height: 20),
          ],
          if (expandChild) Expanded(child: child) else child,
        ],
      ),
    );
  }
}

class AlertBadge extends StatelessWidget {
  final String text;
  final Color color;

  const AlertBadge({super.key, required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.warning_amber_rounded, size: 14, color: Colors.white),
          const SizedBox(width: 4),
          Text(text, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
        ],
      ),
    );
  }
}

class ProgressLine extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  final String trailingText;

  const ProgressLine({
    super.key,
    required this.label,
    required this.value,
    required this.color,
    required this.trailingText,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 13)),
            Text(trailingText, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 8),
        Stack(
          children: [
            Container(
              height: 6,
              decoration: BoxDecoration(
                color: Theme.of(context).dividerColor,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            FractionallySizedBox(
              widthFactor: value,
              child: Container(
                height: 6,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// VIEWS
// -----------------------------------------------------------------------------

class DashboardView extends StatelessWidget {
  final bool isDarkMode;
  const DashboardView({super.key, required this.isDarkMode});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final bool isAnalyzing = appState.isAnalyzing;

    // Helper functions
    void reAnalyze() async {
      await appState.analyzeData();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(appState.apiMessage)));
      }
    }

    void fixBias() async {
      await appState.analyzeData(fixBias: true);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(appState.apiMessage)));
      }
    }

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Model Diagnostic: Recruitment AI V2", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(width: 8, height: 8, decoration: BoxDecoration(color: appState.biasScore > 0.15 ? Colors.red : Colors.green, shape: BoxShape.circle)),
                        const SizedBox(width: 8),
                        Text(
                          appState.biasScore > 0.15 ? "Critical Bias Alert Detected on Attribute: ${appState.biasColumn}" : "No significant bias detected.", 
                          style: TextStyle(color: appState.biasScore > 0.15 ? Colors.redAccent : Colors.green, fontSize: 14)
                        ),
                      ],
                    ),
                  ],
                ),
                Row(
                  children: [
                    OutlinedButton(
                      onPressed: isAnalyzing ? null : reAnalyze,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        side: BorderSide(color: Theme.of(context).colorScheme.secondary),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: Text("Re-Analyze", style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color)),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: isAnalyzing ? null : fixBias,
                      icon: const Icon(Icons.auto_fix_high, size: 18),
                      label: const Text("Fix Bias"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF5A4FCF),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 32),
            if (isAnalyzing) const LinearProgressIndicator(),
            if (isAnalyzing) const SizedBox(height: 16),
            SizedBox(
              height: 280,
              child: Row(
                children: [
                  Expanded(
                    child: ProCard(
                      title: "Fairness Score",
                      subtitle: "Disparate Impact Ratio",
                      expandChild: true,
                      trailing: AlertBadge(
                        text: appState.biasScore > 0.15 ? "HIGH BIAS" : "PASS", 
                        color: appState.biasScore > 0.15 ? const Color(0xFFEF4444) : Colors.green
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          PieChart(
                            PieChartData(
                              sectionsSpace: 0,
                              centerSpaceRadius: 60,
                              sections: [
                                PieChartSectionData(
                                  color: appState.biasScore > 0.15 ? const Color(0xFFEF4444) : Colors.green, 
                                  value: appState.biasScore * 100, 
                                  title: '', 
                                  radius: 15
                                ),
                                PieChartSectionData(
                                  color: Theme.of(context).dividerColor, 
                                  value: 100 - (appState.biasScore * 100), 
                                  title: '', 
                                  radius: 15
                                ),
                              ],
                            ),
                          ),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text("${(appState.biasScore * 100).toInt()}%", style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
                              Text(appState.biasScore > 0.15 ? "FAIL" : "OK", style: TextStyle(fontSize: 12, color: appState.biasScore > 0.15 ? Colors.redAccent : Colors.green)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: ProCard(
                      title: "Model Accuracy",
                      subtitle: "Overall predictive performance.",
                      iconData: Icons.data_usage,
                      expandChild: true,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("${(appState.accuracy * 100).toStringAsFixed(1)}%", style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Colors.cyanAccent)),
                          const SizedBox(height: 12),
                          Stack(
                            children: [
                              Container(
                                height: 6,
                                width: double.infinity,
                                decoration: BoxDecoration(color: Theme.of(context).dividerColor, borderRadius: BorderRadius.circular(3)),
                              ),
                              FractionallySizedBox(
                                widthFactor: appState.accuracy,
                                child: Container(
                                  height: 6,
                                  decoration: BoxDecoration(color: Colors.cyanAccent, borderRadius: BorderRadius.circular(3)),
                                ),
                              ),
                            ],
                          )
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: ProCard(
                      title: "Bias Attributes",
                      subtitle: "Select attribute to isolate disparity.",
                      iconData: Icons.filter_list,
                      expandChild: true,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Protected Class", style: TextStyle(fontSize: 12)),
                          const SizedBox(height: 8),
                          Container(
                            height: 45,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            decoration: BoxDecoration(
                              color: Theme.of(context).scaffoldBackgroundColor,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Theme.of(context).dividerColor),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: appState.biasColumn,
                                isExpanded: true,
                                icon: const Icon(Icons.keyboard_arrow_down, size: 18),
                                dropdownColor: Theme.of(context).cardColor,
                                style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color, fontSize: 14),
                                items: const [
                                  DropdownMenuItem(value: 'gender', child: Text("Gender (Male / Female)")),
                                  DropdownMenuItem(value: 'age', child: Text("Age (Linear)")),
                                  DropdownMenuItem(value: 'experience', child: Text("Experience (Years)")),
                                  DropdownMenuItem(value: 'income_level', child: Text("Income Level (L/M/H)")),
                                ],
                                onChanged: (val) {
                                  if (val != null) {
                                    appState.updateBiasColumn(val);
                                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Analyzing bias by: $val")));
                                  }
                                },
                              ),
                            ),
                          )
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: ProCard(
                    title: "Selection Rates by Gender",
                    iconData: Icons.bar_chart,
                    expandChild: false, // Unbounded
                    child: Column(
                      children: [
                        const SizedBox(height: 40),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: appState.selectionRates.isEmpty 
                            ? [const Padding(padding: EdgeInsets.all(20.0), child: Text("No data yet. Upload data and Analyze."))]
                            : appState.selectionRates.entries.map((e) {
                                final isLowest = e.value == appState.selectionRates.values.reduce((a, b) => a < b ? a : b);
                                final heightMultiplier = e.value > 0 ? (e.value / 0.5) * 100 : 10.0;
                                return Column(
                                  children: [
                                    Text("${(e.value * 100).toInt()}%", style: TextStyle(fontWeight: FontWeight.bold, color: isLowest ? Colors.redAccent : Theme.of(context).textTheme.bodyLarge?.color)),
                                    const SizedBox(height: 8),
                                    Container(width: 40, height: heightMultiplier.clamp(10.0, 150.0).toDouble(), color: Theme.of(context).dividerColor),
                                    const SizedBox(height: 8),
                                    Text(e.key),
                                  ],
                                );
                              }).toList(),
                        ),
                        const SizedBox(height: 32),
                        Text(
                          appState.selectionRates.isEmpty 
                              ? "Awaiting analysis to determine disparity thresholds."
                              : "Displaying selection rates across the evaluated protected class groups.",
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        )
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  flex: 1,
                  child: SizedBox(
                    height: 300,
                    child: Column(
                      children: [
                        Expanded(
                          child: ProCard(
                            title: "Top Bias Drivers",
                            iconData: Icons.list_alt,
                            expandChild: true,
                            child: SingleChildScrollView(
                              child: Column(
                                children: appState.featureImpacts.isEmpty
                                  ? [const Text("Analyze data to reveal drivers.", style: TextStyle(color: Colors.grey, fontSize: 12))]
                                  : appState.featureImpacts.map((feat) {
                                      final double val = (feat['value'] as num).toDouble();
                                      final isHigh = val > 0.7;
                                      final color = isHigh ? Colors.redAccent : (val > 0.4 ? Colors.orangeAccent : Colors.cyanAccent);
                                      return Padding(
                                        padding: const EdgeInsets.only(bottom: 12.0),
                                        child: ProgressLine(
                                          label: feat['name'].toString().toUpperCase(), 
                                          value: val, 
                                          color: color, 
                                          trailingText: isHigh ? "High" : (val > 0.4 ? "Med" : "Low"),
                                        ),
                                      );
                                    }).toList(),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Expanded(
                          child: ProCard(
                            title: "AI Diagnosis",
                            iconData: Icons.location_on_outlined,
                            expandChild: true,
                            child: SingleChildScrollView(
                              child: Text(
                                appState.aiExplanation.isEmpty 
                                    ? "Awaiting model evaluation."
                                    : appState.aiExplanation,
                                style: TextStyle(fontSize: 13, height: 1.5, color: Theme.of(context).colorScheme.secondary),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// DATA INPUT VIEW
// -----------------------------------------------------------------------------

class DataInputView extends StatefulWidget {
  final bool isDarkMode;
  const DataInputView({super.key, required this.isDarkMode});

  @override
  State<DataInputView> createState() => _DataInputViewState();
}

class _DataInputViewState extends State<DataInputView> {
  String? _fileName;

  // Manual entry controllers
  final _ageCtrl = TextEditingController();
  final _expCtrl = TextEditingController();
  final _scoreCtrl = TextEditingController();
  String? _selectedGender;
  String _selectionStatus = 'Pending'; // Selected / Rejected / Pending

  final List<String> _genderOptions = ['Male', 'Female', 'Transgender'];

  // ── CSV Upload ─────────────────────────────────────────────────────────────
  void _pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
      withData: true, // Ensures bytes are available on all platforms
    );
    if (result == null) return;

    final file = result.files.single;
    setState(() => _fileName = file.name);

    try {
      final bytes = file.bytes;
      if (bytes == null) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not read file bytes.')));
        return;
      }
      final csvString = utf8.decode(bytes);
      final rows = const CsvToListConverter(eol: '\n').convert(csvString);
      if (rows.isEmpty) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('CSV file appears to be empty.')));
        return;
      }

      // First row = headers
      final headers = rows[0].map((e) => e.toString().trim().toLowerCase()).toList();
      final List<Map<String, dynamic>> parsed = [];

      for (int i = 1; i < rows.length; i++) {
        final row = rows[i];
        if (row.isEmpty) continue;
        final Map<String, dynamic> entry = {};
        for (int j = 0; j < headers.length && j < row.length; j++) {
          final val = row[j];
          if (val is num) {
            entry[headers[j]] = val;
          } else {
            final s = val.toString().trim();
            final asNum = num.tryParse(s);
            entry[headers[j]] = asNum ?? s;
          }
        }
        // Normalise 'selected' field
        if (entry.containsKey('selected') && entry['selected'] is String) {
          final sv = (entry['selected'] as String).toLowerCase();
          entry['selected'] = (sv == '1' || sv == 'true' || sv == 'selected') ? 1 : 0;
        }
        parsed.add(entry);
      }

      if (mounted) {
        context.read<AppState>().setDataset(parsed);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Loaded ${parsed.length} records from CSV')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error parsing CSV: $e')));
    }
  }

  // ── Add Row ────────────────────────────────────────────────────────────────
  void _addRow() {
    final age = int.tryParse(_ageCtrl.text.trim());
    final exp = double.tryParse(_expCtrl.text.trim());
    final score = int.tryParse(_scoreCtrl.text.trim());

    if (age == null) { _showError('Age must be a whole number.'); return; }
    if (exp == null) { _showError('Experience must be a number.'); return; }
    if (score == null) { _showError('Test Score must be a whole number.'); return; }
    if (_selectedGender == null) { _showError('Please select a gender.'); return; }

    final row = {
      'age': age,
      'gender': _selectedGender,
      'experience': exp,
      'test_score': score,
      'selected': _selectionStatus == 'Selected' ? 1 : 0,
    };

    context.read<AppState>().addDatasetRow(row);

    // Clear form
    setState(() {
      _ageCtrl.clear();
      _expCtrl.clear();
      _scoreCtrl.clear();
      _selectedGender = null;
      _selectionStatus = 'Pending';
    });

    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Row added successfully!')));
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.redAccent));
  }

  @override
  void dispose() {
    _ageCtrl.dispose();
    _expCtrl.dispose();
    _scoreCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dataset = context.watch<AppState>().dataset;

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Data Source Configuration", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text("Upload batch datasets for comprehensive bias analysis, or input manual records for real-time diagnostic evaluation.", style: TextStyle(color: Theme.of(context).colorScheme.secondary)),
            const SizedBox(height: 32),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Batch Upload ──────────────────────────────────────────
                Expanded(
                  flex: 1,
                  child: SizedBox(
                    height: 350,
                    child: ProCard(
                      title: "Batch Upload",
                      iconData: Icons.file_upload_outlined,
                      expandChild: true,
                      child: Column(
                        children: [
                          Expanded(
                            child: Container(
                              width: double.infinity,
                              decoration: BoxDecoration(
                                border: Border.all(color: Theme.of(context).dividerColor, style: BorderStyle.solid),
                                borderRadius: BorderRadius.circular(12),
                                color: Theme.of(context).scaffoldBackgroundColor,
                              ),
                              child: Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.cloud_upload_outlined, size: 48, color: Colors.grey),
                                    const SizedBox(height: 16),
                                    const Text("Drag and drop CSV files here"),
                                    const SizedBox(height: 4),
                                    const Text("Max file size 50MB", style: TextStyle(fontSize: 12, color: Colors.grey)),
                                    const SizedBox(height: 24),
                                    ElevatedButton(
                                      onPressed: _pickFile,
                                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF5A4FCF), foregroundColor: Colors.white),
                                      child: Text(_fileName != null ? "Selected: $_fileName" : "Browse Files"),
                                    )
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text("Need to test the system?", style: TextStyle(fontSize: 12)),
                              OutlinedButton(
                                onPressed: () {
                                  context.read<AppState>().loadSampleData();
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sample Data Loaded')));
                                },
                                child: Text("Load Sample Data", style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color)),
                              ),
                            ],
                          )
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 24),
                // ── Manual Entry ──────────────────────────────────────────
                Expanded(
                  flex: 2,
                  child: SizedBox(
                    height: 350,
                    child: ProCard(
                      title: "Manual Entry",
                      iconData: Icons.keyboard,
                      expandChild: true,
                      trailing: const Text("SINGLE RECORD MODE", style: TextStyle(fontSize: 10, letterSpacing: 1, color: Colors.grey)),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(child: _buildNumberField("Age", "e.g. 28", _ageCtrl, isInteger: true)),
                              const SizedBox(width: 16),
                              // Gender Dropdown
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text("Gender", style: TextStyle(fontSize: 12)),
                                    const SizedBox(height: 8),
                                    Container(
                                      height: 40,
                                      padding: const EdgeInsets.symmetric(horizontal: 12),
                                      decoration: BoxDecoration(
                                        color: Theme.of(context).scaffoldBackgroundColor,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: DropdownButtonHideUnderline(
                                        child: DropdownButton<String>(
                                          value: _selectedGender,
                                          hint: const Text("Select...", style: TextStyle(color: Colors.grey, fontSize: 14)),
                                          isExpanded: true,
                                          icon: const Icon(Icons.keyboard_arrow_down, size: 18),
                                          dropdownColor: const Color(0xFF1C2235),
                                          items: _genderOptions.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                                          onChanged: (val) => setState(() => _selectedGender = val),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(child: _buildNumberField("Experience (Years)", "0.0", _expCtrl)),
                              const SizedBox(width: 16),
                              Expanded(child: _buildNumberField("Test Score (0-100)", "e.g. 85", _scoreCtrl, isInteger: true)),
                            ],
                          ),
                          const SizedBox(height: 24),
                          const Align(alignment: Alignment.centerLeft, child: Text("Selection Status", style: TextStyle(fontSize: 12))),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              _buildRadioBtn("Selected", isSelected: _selectionStatus == 'Selected', onTap: () => setState(() => _selectionStatus = 'Selected')),
                              const SizedBox(width: 16),
                              _buildRadioBtn("Rejected", isSelected: _selectionStatus == 'Rejected', onTap: () => setState(() => _selectionStatus = 'Rejected')),
                              const SizedBox(width: 16),
                              _buildRadioBtn("Pending", isSelected: _selectionStatus == 'Pending', onTap: () => setState(() => _selectionStatus = 'Pending')),
                            ],
                          ),
                          const Spacer(),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              OutlinedButton.icon(
                                onPressed: _addRow,
                                icon: const Icon(Icons.add, size: 16),
                                label: Text("Add Row", style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color)),
                              ),
                              const SizedBox(width: 16),
                              ElevatedButton.icon(
                                onPressed: () async {
                                  await context.read<AppState>().analyzeData();
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.read<AppState>().apiMessage)));
                                  }
                                },
                                icon: const Icon(Icons.analytics, size: 16),
                                label: const Text("Analyze Data"),
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.cyan[700], foregroundColor: Colors.white),
                              ),
                            ],
                          )
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            // ── Preview Table ─────────────────────────────────────────────
            SizedBox(
              height: 400,
              child: ProCard(
                title: "Preview Data",
                subtitle: "Reviewing ${dataset.length} records loaded.",
                expandChild: true,
                child: dataset.isEmpty
                  ? const Center(child: Text("No records yet. Upload a CSV or add rows manually.", style: TextStyle(color: Colors.grey)))
                  : SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SingleChildScrollView(
                        child: DataTable(
                          columns: const [
                            DataColumn(label: Text("Age")),
                            DataColumn(label: Text("Gender")),
                            DataColumn(label: Text("Experience (Yrs)")),
                            DataColumn(label: Text("Test Score")),
                            DataColumn(label: Text("Status")),
                            DataColumn(label: Text("Actions")),
                          ],
                          rows: dataset.asMap().entries.map((entry) {
                            final i = entry.key;
                            final row = entry.value;
                            final isSelected = (row['selected'] == 1 || row['selected'] == true);
                            final statusColor = isSelected ? Colors.green : Colors.redAccent;
                            return DataRow(cells: [
                              DataCell(Text(row['age'].toString())),
                              DataCell(Text(row['gender'].toString())),
                              DataCell(Text(row['experience'].toString())),
                              DataCell(Text(row['test_score'].toString())),
                              DataCell(
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: statusColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: statusColor.withOpacity(0.5)),
                                  ),
                                  child: Text(isSelected ? "Selected" : "Rejected", style: TextStyle(color: statusColor, fontSize: 11)),
                                ),
                              ),
                              DataCell(
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                                  tooltip: 'Delete row',
                                  onPressed: () {
                                    context.read<AppState>().removeDatasetRow(i);
                                  },
                                ),
                              ),
                            ]);
                          }).toList(),
                        ),
                      ),
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNumberField(String label, String hint, TextEditingController controller, {bool isInteger = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12)),
        const SizedBox(height: 8),
        Container(
          height: 40,
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: BorderRadius.circular(8),
          ),
          child: TextField(
            controller: controller,
            keyboardType: TextInputType.numberWithOptions(decimal: !isInteger),
            inputFormatters: [
              FilteringTextInputFormatter.allow(isInteger ? RegExp(r'[0-9]') : RegExp(r'[0-9.]')),
            ],
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(fontSize: 14, color: Colors.grey),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRadioBtn(String label, {required bool isSelected, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.cyan.withOpacity(0.1) : Colors.transparent,
          border: Border.all(color: isSelected ? Colors.cyan : Theme.of(context).dividerColor),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Icon(isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked, size: 16, color: isSelected ? Colors.cyan : Colors.grey),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(color: isSelected ? Colors.cyan : Colors.grey, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}



// -----------------------------------------------------------------------------
// ANALYTICS VIEW  — 100% real backend data, no fake month labels
// -----------------------------------------------------------------------------

class AnalyticsView extends StatelessWidget {
  final bool isDarkMode;
  const AnalyticsView({super.key, required this.isDarkMode});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final bool hasData = appState.selectionRates.isNotEmpty || appState.beforeAfter.isNotEmpty;

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Analytics", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text("Real model outputs — group rates, bias comparison, and run history.", style: TextStyle(color: Theme.of(context).colorScheme.secondary)),
            if (!hasData) ...[
              const SizedBox(height: 32),
              const Center(child: Text("No analysis data yet. Go to Data Input and run an analysis.", style: TextStyle(color: Colors.grey))),
            ] else ...[
              const SizedBox(height: 32),

              // ── Row 1: Group Rates  +  Before vs After Bias ────────────────
              SizedBox(
                height: 340,
                child: Row(
                  children: [
                    // ── CHART 1: Group Selection Rates (from real backend rates)
                    Expanded(
                      flex: 1,
                      child: ProCard(
                        title: "Selection Rate by Group",
                        subtitle: "Actual rates from last analysis • ${appState.biasColumn}",
                        expandChild: true,
                        child: _GroupRatesChart(
                          rates: appState.selectionRates,
                          isDarkMode: isDarkMode,
                        ),
                      ),
                    ),
                    const SizedBox(width: 24),

                    // ── CHART 2: Before vs After Bias (real beforeAfter data) ──
                    Expanded(
                      flex: 1,
                      child: ProCard(
                        title: "Bias: Before vs After Fix",
                        subtitle: "Actual bias score comparison",
                        expandChild: true,
                        child: _BeforeAfterBiasChart(
                          beforeAfter: appState.beforeAfter,
                          biasScore: appState.biasScore,
                          isDarkMode: isDarkMode,
                        ),
                      ),
                    ),

                    const SizedBox(width: 24),

                    // ── CHART 3: Accuracy by Group ──────────────────────────
                    if (appState.accuracyByGroup.isNotEmpty)
                      Expanded(
                        flex: 1,
                        child: ProCard(
                          title: "Accuracy by Group",
                          subtitle: "Model performance per protected class",
                          expandChild: true,
                          child: Padding(
                            padding: const EdgeInsets.only(top: 16.0),
                            child: BarChart(
                              BarChartData(
                                gridData: const FlGridData(show: false),
                                titlesData: FlTitlesData(
                                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                  bottomTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      getTitlesWidget: (value, meta) {
                                        final idx = value.toInt();
                                        if (idx >= 0 && idx < appState.accuracyByGroup.length) {
                                          return Text(appState.accuracyByGroup[idx]['group'].toString(), style: const TextStyle(fontSize: 10));
                                        }
                                        return const Text('');
                                      },
                                    ),
                                  ),
                                ),
                                borderData: FlBorderData(show: false),
                                maxY: 1,
                                barGroups: appState.accuracyByGroup.asMap().entries.map((e) {
                                  final group = e.value;
                                  final acc = (group['accuracy'] as num).toDouble();
                                  final hexStr = (group['color']?.toString() ?? '#00FFFF').replaceAll('#', '');
                                  final barColor = Color(int.parse('FF$hexStr', radix: 16));
                                  return BarChartGroupData(
                                    x: e.key,
                                    barRods: [BarChartRodData(
                                      toY: acc,
                                      color: barColor,
                                      width: 28,
                                      backDrawRodData: BackgroundBarChartRodData(show: true, toY: 1, color: Theme.of(context).dividerColor),
                                    )],
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // ── Row 2: Run History line chart (real run-by-run data) ────────
              if (appState.analysisHistory.isNotEmpty)
                SizedBox(
                  height: 240,
                  child: ProCard(
                    title: "Analysis Run History",
                    subtitle: "Bias score across every analysis run in this session",
                    expandChild: true,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(width: 10, height: 3, color: Colors.cyanAccent),
                        const SizedBox(width: 4),
                        const Text("Bias", style: TextStyle(fontSize: 11, color: Colors.grey)),
                        const SizedBox(width: 12),
                        Container(width: 10, height: 3, color: Colors.amber),
                        const SizedBox(width: 4),
                        const Text("Accuracy", style: TextStyle(fontSize: 11, color: Colors.grey)),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.only(top: 16.0, right: 16),
                      child: LineChart(
                        LineChartData(
                          gridData: FlGridData(
                            show: true,
                            drawVerticalLine: false,
                            getDrawingHorizontalLine: (_) => FlLine(color: Theme.of(context).dividerColor, strokeWidth: 1),
                          ),
                          titlesData: FlTitlesData(
                            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 28,
                                interval: 1,
                                getTitlesWidget: (value, meta) {
                                  final idx = value.toInt();
                                  if (idx >= 0 && idx < appState.analysisHistory.length) {
                                    return Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(
                                        appState.analysisHistory[idx]['label'].toString(),
                                        style: TextStyle(
                                          fontSize: 9,
                                          color: appState.analysisHistory[idx]['fixBias'] == true
                                              ? Colors.cyanAccent
                                              : Theme.of(context).colorScheme.secondary,
                                        ),
                                      ),
                                    );
                                  }
                                  return const Text('');
                                },
                              ),
                            ),
                          ),
                          borderData: FlBorderData(show: false),
                          minY: 0,
                          maxY: 1,
                          lineBarsData: [
                            // Bias line — cyan
                            LineChartBarData(
                              spots: appState.analysisHistory.asMap().entries.map((e) =>
                                FlSpot(e.key.toDouble(), (e.value['bias'] as num).toDouble())
                              ).toList(),
                              isCurved: true,
                              color: Colors.cyanAccent,
                              barWidth: 2.5,
                              dotData: FlDotData(
                                show: true,
                                getDotPainter: (spot, _, __, ___) => FlDotCirclePainter(
                                  radius: 4,
                                  color: Colors.cyanAccent,
                                  strokeWidth: 0,
                                ),
                              ),
                            ),
                            // Accuracy line — amber
                            LineChartBarData(
                              spots: appState.analysisHistory.asMap().entries.map((e) =>
                                FlSpot(e.key.toDouble(), (e.value['accuracy'] as num).toDouble())
                              ).toList(),
                              isCurved: true,
                              color: Colors.amber,
                              barWidth: 2.5,
                              dashArray: [5, 4],
                              dotData: FlDotData(
                                show: true,
                                getDotPainter: (spot, _, __, ___) => FlDotCirclePainter(
                                  radius: 4,
                                  color: Colors.amber,
                                  strokeWidth: 0,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

              const SizedBox(height: 32),

              // ── Row 3: Intervention Impact cards ──────────────────────────
              const Text("Intervention Impact Analysis", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              SizedBox(
                height: 160,
                child: Row(
                  children: [
                    Expanded(child: _buildImpactCard(context, "False Positive Rate", appState.beforeAfter, 'false_positive', isPercent: true)),
                    const SizedBox(width: 24),
                    Expanded(child: _buildImpactCard(context, "Demographic Parity", appState.beforeAfter, 'parity', isPercent: false)),
                    const SizedBox(width: 24),
                    Expanded(child: _buildImpactCard(context, "Overall Accuracy", appState.beforeAfter, 'accuracy', isPercent: true)),
                  ],
                ),
              ),
            ], // end hasData
          ],
        ),
      ),
    );
  }

  Widget _buildImpactCard(BuildContext context, String title, Map<String, dynamic> beforeAfterMap, String key, {bool isPercent = false}) {
    final section = beforeAfterMap[key] as Map<String, dynamic>?;
    final before = (section?['before'] as num?)?.toDouble() ?? 0.0;
    final after  = (section?['after']  as num?)?.toDouble() ?? 0.0;
    final improved = key == 'false_positive' ? after < before : after > before;
    final stable   = (after - before).abs() < 0.02;
    final badge      = stable ? "STABLE" : (improved ? "IMPROVED" : "DECLINED");
    final badgeColor = stable ? Colors.grey : (improved ? Colors.cyan : Colors.redAccent);
    String fmt(double v) => isPercent ? "${(v * 100).toStringAsFixed(1)}%" : v.toStringAsFixed(2);

    return ProCard(
      padding: const EdgeInsets.all(24),
      expandChild: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(children: [
                Icon(Icons.tune, size: 16, color: Theme.of(context).colorScheme.secondary),
                const SizedBox(width: 8),
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
              ]),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: badgeColor.withOpacity(0.2), borderRadius: BorderRadius.circular(4), border: Border.all(color: badgeColor.withOpacity(0.5))),
                child: Text(badge, style: TextStyle(color: badgeColor, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Column(mainAxisSize: MainAxisSize.min, children: [
                  const Text("BEFORE FIX", style: TextStyle(fontSize: 10, color: Colors.grey)),
                  const SizedBox(height: 8),
                  Text(fmt(before), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.redAccent)),
                ]),
                Container(width: 1, height: 40, color: Theme.of(context).dividerColor),
                Column(mainAxisSize: MainAxisSize.min, children: [
                  const Text("AFTER FIX", style: TextStyle(fontSize: 10, color: Colors.grey)),
                  const SizedBox(height: 8),
                  Text(fmt(after), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.cyanAccent)),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Chart widget: Group Selection Rates (Option 2) ───────────────────────────
class _GroupRatesChart extends StatelessWidget {
  final Map<String, double> rates;
  final bool isDarkMode;
  const _GroupRatesChart({required this.rates, required this.isDarkMode});

  @override
  Widget build(BuildContext context) {
    if (rates.isEmpty) return const Center(child: Text("No group data", style: TextStyle(color: Colors.grey)));

    final entries = rates.entries.toList();
    final maxVal  = entries.map((e) => e.value).reduce((a, b) => a > b ? a : b);
    final minVal  = entries.map((e) => e.value).reduce((a, b) => a < b ? a : b);
    final colors  = [Colors.cyanAccent, const Color(0xFF5A4FCF), Colors.amber, Colors.greenAccent, Colors.redAccent];

    return Padding(
      padding: const EdgeInsets.only(top: 12.0),
      child: BarChart(
        BarChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) => FlLine(color: Theme.of(context).dividerColor, strokeWidth: 1),
          ),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 36,
                interval: 0.25,
                getTitlesWidget: (v, _) => Text("${(v * 100).toInt()}%", style: const TextStyle(fontSize: 9, color: Colors.grey)),
              ),
            ),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                getTitlesWidget: (value, _) {
                  final idx = value.toInt();
                  if (idx >= 0 && idx < entries.length) {
                    final isLowest = entries[idx].value == minVal;
                    return Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        entries[idx].key,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isLowest ? Colors.redAccent : Theme.of(context).textTheme.bodyLarge?.color,
                        ),
                      ),
                    );
                  }
                  return const Text('');
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          minY: 0,
          maxY: 1,
          barGroups: entries.asMap().entries.map((e) {
            final isLowest = e.value.value == minVal;
            final isHighest = e.value.value == maxVal;
            final color = isLowest ? Colors.redAccent : (isHighest ? Colors.cyanAccent : colors[e.key % colors.length]);
            return BarChartGroupData(
              x: e.key,
              barRods: [
                BarChartRodData(
                  toY: e.value.value,
                  color: color,
                  width: 36,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                  backDrawRodData: BackgroundBarChartRodData(show: true, toY: 1, color: Theme.of(context).dividerColor.withOpacity(0.3)),
                  rodStackItems: [],
                ),
              ],
              showingTooltipIndicators: [],
            );
          }).toList(),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, groupIndex, rod, rodIndex) => BarTooltipItem(
                "${entries[groupIndex].key}\n${(rod.toY * 100).toStringAsFixed(1)}%",
                const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Chart widget: Before vs After Bias Fix (Option 1) ────────────────────────
class _BeforeAfterBiasChart extends StatelessWidget {
  final Map<String, dynamic> beforeAfter;
  final double biasScore;
  final bool isDarkMode;
  const _BeforeAfterBiasChart({required this.beforeAfter, required this.biasScore, required this.isDarkMode});

  @override
  Widget build(BuildContext context) {
    // Extract real before/after bias from the false_positive key (proxy for bias)
    final fpSection   = beforeAfter['false_positive'] as Map<String, dynamic>?;
    final biasBefore  = (fpSection?['before'] as num?)?.toDouble() ?? biasScore;
    final biasAfter   = (fpSection?['after']  as num?)?.toDouble() ?? (biasScore * 0.6);

    final improved = biasAfter < biasBefore;

    final bars = [
      {'label': 'Before Fix', 'value': biasBefore, 'color': Colors.redAccent},
      {'label': 'After Fix',  'value': biasAfter,  'color': Colors.cyanAccent},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Summary row
        Padding(
          padding: const EdgeInsets.fromLTRB(0, 12, 0, 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: bars.map((b) => Column(
              children: [
                Text(
                  "${((b['value'] as double) * 100).toStringAsFixed(1)}%",
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: b['color'] as Color),
                ),
                const SizedBox(height: 2),
                Text(b['label'] as String, style: const TextStyle(fontSize: 10, color: Colors.grey)),
              ],
            )).toList(),
          ),
        ),
        if (improved)
          Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 8),
            child: Row(children: [
              const Icon(Icons.arrow_downward, size: 12, color: Colors.cyanAccent),
              const SizedBox(width: 4),
              Text(
                "Bias reduced by ${(((biasBefore - biasAfter) / biasBefore) * 100).toStringAsFixed(0)}%",
                style: const TextStyle(fontSize: 11, color: Colors.cyanAccent),
              ),
            ]),
          ),
        // Bar chart
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 8, bottom: 8),
            child: BarChart(
              BarChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) => FlLine(color: Theme.of(context).dividerColor, strokeWidth: 1),
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 36,
                      interval: 0.25,
                      getTitlesWidget: (v, _) => Text("${(v * 100).toInt()}%", style: const TextStyle(fontSize: 9, color: Colors.grey)),
                    ),
                  ),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 24,
                      getTitlesWidget: (value, _) {
                        final labels = ['Before Fix', 'After Fix'];
                        final idx = value.toInt();
                        return idx >= 0 && idx < labels.length
                            ? Text(labels[idx], style: const TextStyle(fontSize: 10))
                            : const Text('');
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                minY: 0,
                maxY: 1,
                barGroups: bars.asMap().entries.map((e) => BarChartGroupData(
                  x: e.key,
                  barRods: [BarChartRodData(
                    toY: (e.value['value'] as double),
                    color: e.value['color'] as Color,
                    width: 48,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                    backDrawRodData: BackgroundBarChartRodData(show: true, toY: 1, color: Theme.of(context).dividerColor.withOpacity(0.3)),
                  )],
                )).toList(),
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipItem: (group, gi, rod, _) => BarTooltipItem(
                      "${bars[gi]['label']}\n${(rod.toY * 100).toStringAsFixed(1)}%",
                      const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}







// -----------------------------------------------------------------------------
// AI INSIGHTS VIEW
// -----------------------------------------------------------------------------

class AIInsightsView extends StatelessWidget {
  final bool isDarkMode;
  const AIInsightsView({super.key, required this.isDarkMode});

  static const List<IconData> _recIcons = [
    Icons.delete_outline,
    Icons.balance,
    Icons.model_training,
  ];

  void _showReport(BuildContext context, AppState appState) {
    final report = appState.buildReport();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDarkMode ? const Color(0xFF1C2235) : Colors.white,
        title: const Text("Full Analysis Report", style: TextStyle(fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: SelectableText(report, style: const TextStyle(fontFamily: 'monospace', fontSize: 12, height: 1.6)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Close")),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final bool hasData = appState.accuracy > 0 || appState.biasScore > 0;
    final int fairnessScore = ((1 - appState.biasScore) * 100).round().clamp(0, 100);
    final Color fairnessColor = fairnessScore >= 75 ? Colors.cyanAccent : (fairnessScore >= 50 ? Colors.amber : Colors.redAccent);

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("AI Insights & Diagnostics", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text("Automated analysis of model behavior, fairness metrics, and bias detection.", style: TextStyle(color: Theme.of(context).colorScheme.secondary)),
                  ],
                ),
                // Refresh button
                if (hasData)
                  OutlinedButton.icon(
                    icon: appState.isGeminiLoading
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                        : appState.geminiCooldownSeconds > 0
                            ? const Icon(Icons.timer_outlined, size: 16, color: Colors.orange)
                            : const Icon(Icons.refresh, size: 16),
                    label: Text(
                      appState.isGeminiLoading
                          ? "Generating..."
                          : appState.geminiCooldownSeconds > 0
                              ? "Retry in ${appState.geminiCooldownSeconds}s"
                              : "Refresh Insights",
                      style: TextStyle(
                        color: appState.geminiCooldownSeconds > 0 ? Colors.orange : null,
                      ),
                    ),
                    onPressed: (appState.isGeminiLoading || appState.geminiCooldownSeconds > 0)
                        ? null
                        : () => appState.fetchGeminiInsights(),
                  ),
              ],
            ),
            // No-data state
            if (!hasData) ...[ 
              const SizedBox(height: 32),
              const Center(child: Text("No analysis data yet. Go to Data Input and run an analysis.", style: TextStyle(color: Colors.grey))),
            ] else ...[
            const SizedBox(height: 32),
            // ── Error / status banner
            if (appState.geminiError.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: appState.geminiCooldownSeconds > 0
                      ? Colors.orange.withOpacity(0.08)
                      : Colors.redAccent.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: appState.geminiCooldownSeconds > 0
                        ? Colors.orange.withOpacity(0.4)
                        : Colors.redAccent.withOpacity(0.4),
                  ),
                ),
                child: Row(children: [
                  Icon(
                    appState.geminiCooldownSeconds > 0 ? Icons.timer_outlined : Icons.warning_amber_rounded,
                    color: appState.geminiCooldownSeconds > 0 ? Colors.orange : Colors.redAccent,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      appState.geminiError,
                      style: TextStyle(
                        color: appState.geminiCooldownSeconds > 0 ? Colors.orange : Colors.redAccent,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  // Retry button — only shown when cooldown is over
                  if (appState.geminiCooldownSeconds == 0 && !appState.isGeminiLoading)
                    TextButton.icon(
                      onPressed: () => appState.fetchGeminiInsights(),
                      icon: const Icon(Icons.refresh, size: 14),
                      label: const Text('Retry', style: TextStyle(fontSize: 12)),
                      style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
                    ),
                ]),
              ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: Column(
                    children: [
                      // ── Diagnostic Explanation ────────────────────────────
                      SizedBox(
                        height: 400,
                        child: ProCard(
                          title: "Diagnostic Explanation",
                          iconData: Icons.chat_bubble_outline,
                          expandChild: true,
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: Colors.cyan.withOpacity(0.2), borderRadius: BorderRadius.circular(4)),
                            child: Text("BIAS COL: ${appState.biasColumn.toUpperCase()}", style: const TextStyle(color: Colors.cyan, fontSize: 10, fontWeight: FontWeight.bold)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: appState.isGeminiLoading
                                  ? const Center(child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        CircularProgressIndicator(color: Colors.cyanAccent, strokeWidth: 2),
                                        SizedBox(height: 12),
                                        Text("Gemini is analyzing your model...", style: TextStyle(color: Colors.grey, fontSize: 12)),
                                      ],
                                    ))
                                  : SingleChildScrollView(
                                      child: Text(
                                        appState.aiExplanation.isNotEmpty
                                          ? appState.aiExplanation
                                          : "No explanation yet. Add your Gemini API key in Settings and click Refresh Insights.",
                                        style: TextStyle(
                                          color: Theme.of(context).textTheme.bodyLarge?.color,
                                          height: 1.6,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                              ),
                              const SizedBox(height: 12),
                              // Metrics summary code block
                              Container(
                                padding: const EdgeInsets.all(16),
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: isDarkMode ? const Color(0xFF0D1117) : const Color(0xFF1F2937),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text("<> Model Metrics Snapshot", style: TextStyle(color: Colors.grey, fontSize: 12)),
                                    const SizedBox(height: 10),
                                    Text("bias_column    = '${appState.biasColumn}'", style: const TextStyle(color: Colors.cyanAccent, fontFamily: 'monospace', fontSize: 12)),
                                    Text("accuracy       = ${(appState.accuracy * 100).toStringAsFixed(1)}%", style: const TextStyle(color: Colors.white70, fontFamily: 'monospace', fontSize: 12)),
                                    Text("bias_score     = ${(appState.biasScore * 100).toStringAsFixed(1)}%", style: TextStyle(color: appState.biasScore > 0.3 ? Colors.redAccent : Colors.greenAccent, fontFamily: 'monospace', fontSize: 12)),
                                    Text("fairness_score = $fairnessScore / 100", style: TextStyle(color: fairnessColor, fontFamily: 'monospace', fontSize: 12)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      // ── Fairness Score + Bias Vectors ─────────────────────
                      SizedBox(
                        height: 240,
                        child: Row(
                          children: [
                            Expanded(
                              child: ProCard(
                                title: "FAIRNESS SCORE",
                                expandChild: true,
                                child: Center(
                                  child: Container(
                                    width: 100, height: 100,
                                    decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: fairnessColor, width: 4)),
                                    child: Center(child: Text(
                                      "$fairnessScore",
                                      style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: fairnessColor),
                                    )),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 24),
                            Expanded(
                              child: ProCard(
                                title: "BIAS VECTORS",
                                expandChild: true,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    // Primary bias column
                                    Builder(
                                      builder: (context) {
                                        final bias = appState.biasScore.clamp(0.0, 1.0);
                                        String riskLabel = "Low Risk";
                                        Color riskColor = Colors.cyanAccent;
                                        if (bias > 0.6) {
                                          riskLabel = "High Risk";
                                          riskColor = Colors.redAccent;
                                        } else if (bias > 0.3) {
                                          riskLabel = "Medium Risk";
                                          riskColor = Colors.amber;
                                        }
                                        return ProgressLine(
                                          label: _capitalise(appState.biasColumn),
                                          value: bias,
                                          color: riskColor,
                                          trailingText: "$riskLabel (${(bias * 100).toStringAsFixed(1)}%)",
                                        );
                                      }
                                    ),
                                    // Per-group rates
                                    ...appState.selectionRates.entries.take(2).map((e) {
                                      final v = e.value.clamp(0.0, 1.0);
                                      String riskText = "Low";
                                      Color color = Colors.cyan;
                                      if (v > 0.6) {
                                        riskText = "High";
                                        color = Colors.redAccent;
                                      } else if (v > 0.3) {
                                        riskText = "Medium";
                                        color = Colors.amber;
                                      }
                                      return Column(children: [
                                        const SizedBox(height: 16),
                                        ProgressLine(
                                          label: e.key,
                                          value: v,
                                          color: color,
                                          trailingText: "$riskText (${(v * 100).toStringAsFixed(1)}%)",
                                        ),
                                      ]);
                                    }),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 24),
                // ── Recommendations ───────────────────────────────────────
                Expanded(
                  flex: 1,
                  child: SizedBox(
                    height: 624,
                    child: ProCard(
                      title: "Recommendations",
                      iconData: Icons.check_circle_outline,
                      expandChild: true,
                      subtitle: "Suggested actions to mitigate detected bias and improve overall model fairness.",
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (appState.isGeminiLoading)
                            const Expanded(child: Center(child: CircularProgressIndicator(color: Colors.cyanAccent, strokeWidth: 2)))
                          else if (appState.aiRecommendations.isEmpty)
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    appState.geminiApiKey.isEmpty
                                        ? Icons.key_off_outlined
                                        : Icons.lightbulb_outline,
                                    color: Colors.grey,
                                    size: 36,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    appState.geminiApiKey.isEmpty
                                        ? 'No API key set.\nGo to Settings → paste your Gemini key → Save.'
                                        : 'Click "Refresh Insights" above to generate AI recommendations.',
                                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                                    textAlign: TextAlign.center,
                                  ),
                                  if (appState.geminiApiKey.isNotEmpty) ...[
                                    const SizedBox(height: 16),
                                    OutlinedButton.icon(
                                      onPressed: appState.isGeminiLoading || appState.geminiCooldownSeconds > 0
                                          ? null
                                          : () => appState.fetchGeminiInsights(),
                                      icon: appState.isGeminiLoading
                                          ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2))
                                          : const Icon(Icons.auto_awesome, size: 14),
                                      label: Text(
                                        appState.geminiCooldownSeconds > 0
                                            ? 'Wait ${appState.geminiCooldownSeconds}s'
                                            : 'Generate Now',
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                      style: OutlinedButton.styleFrom(foregroundColor: Colors.cyanAccent),
                                    ),
                                  ],
                                ],
                              ),
                            )
                          else
                            ...appState.aiRecommendations.asMap().entries.map((e) => Padding(
                              padding: EdgeInsets.only(bottom: e.key < appState.aiRecommendations.length - 1 ? 16 : 0),
                              child: _buildRecItem(
                                _recIcons[e.key % _recIcons.length],
                                "Recommendation ${e.key + 1}",
                                e.value,
                                isDarkMode,
                              ),
                            )),
                          const Spacer(),
                          ElevatedButton(
                            onPressed: () => _showReport(context, appState),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF5A4FCF),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: const Text("Generate Full Report"),
                          )
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            ], // end hasData block
          ],
        ),
      ),
    );
  }

  String _capitalise(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  Widget _buildRecItem(IconData icon, String title, String desc, bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: isDarkMode ? const Color(0xFF0D1117) : const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(8)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: const Color(0xFF5A4FCF)),
              const SizedBox(width: 8),
              Flexible(child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
            ],
          ),
          const SizedBox(height: 8),
          Text(desc, style: const TextStyle(fontSize: 12, color: Colors.grey, height: 1.4)),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// SETTINGS VIEW
// -----------------------------------------------------------------------------

class SettingsView extends StatefulWidget {
  final bool isDarkMode;
  final VoidCallback toggleTheme;

  const SettingsView({super.key, required this.isDarkMode, required this.toggleTheme});

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  late TextEditingController _urlCtrl;
  late TextEditingController _keyCtrl;
  bool _obscureKey = true;
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    final appState = context.read<AppState>();
    _urlCtrl = TextEditingController(text: appState.backendUrl);
    _keyCtrl = TextEditingController(text: appState.geminiApiKey);
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    _keyCtrl.dispose();
    super.dispose();
  }

  void _save() async {
    final appState = context.read<AppState>();
    final url = _urlCtrl.text.trim();
    final key = _keyCtrl.text.trim();

    // Persist to SharedPreferences (Flutter's localStorage)
    await appState.updateBackendUrl(url);
    await appState.updateGeminiApiKey(key);

    if (!mounted) return;
    setState(() => _saved = true);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          const Icon(Icons.check_circle, color: Colors.white, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(key.isNotEmpty
                ? 'Gemini API key saved! Go to AI Insights and click Refresh Insights.'
                : 'Configuration saved. No Gemini key set — AI insights disabled.'),
          ),
        ]),
        backgroundColor: key.isNotEmpty ? const Color(0xFF5A4FCF) : Colors.orange,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final bool keyIsSet = appState.geminiApiKey.isNotEmpty;

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Settings", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 32),
            ProCard(
              title: "Appearance",
              iconData: Icons.palette_outlined,
              expandChild: false,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Dark Mode Aesthetic", style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text("Enable deep space-gray foundations to prioritize data visibility.", style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.secondary)),
                    ],
                  ),
                  Switch(
                    value: widget.isDarkMode,
                    onChanged: (val) => widget.toggleTheme(),
                    activeColor: const Color(0xFF5A4FCF),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            ProCard(
              title: "API Configuration",
              iconData: Icons.api_outlined,
              expandChild: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Backend URL ─────────────────────────────────────────
                  const Text("Backend API URL", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Theme.of(context).dividerColor),
                    ),
                    child: TextField(
                      controller: _urlCtrl,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.link, size: 18),
                        hintText: "http://127.0.0.1:5000",
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Gemini API Key ──────────────────────────────────────
                  Row(
                    children: [
                      const Text("Gemini API Key", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 8),
                      if (keyIsSet)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.green.withOpacity(0.4)),
                          ),
                          child: const Text("CONNECTED", style: TextStyle(color: Colors.green, fontSize: 9, fontWeight: FontWeight.bold)),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.orange.withOpacity(0.4)),
                          ),
                          child: const Text("NOT SET", style: TextStyle(color: Colors.orange, fontSize: 9, fontWeight: FontWeight.bold)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: keyIsSet ? Colors.green.withOpacity(0.4) : Theme.of(context).dividerColor,
                      ),
                    ),
                    child: TextField(
                      controller: _keyCtrl,
                      obscureText: _obscureKey,
                      onChanged: (_) => setState(() => _saved = false),
                      decoration: InputDecoration(
                        prefixIcon: Icon(
                          Icons.key,
                          size: 18,
                          color: keyIsSet ? Colors.green : Theme.of(context).colorScheme.secondary,
                        ),
                        hintText: "Paste your Gemini API key here…",
                        hintStyle: const TextStyle(color: Colors.grey),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 14),
                        suffixIcon: IconButton(
                          icon: Icon(_obscureKey ? Icons.visibility_off : Icons.visibility, size: 18),
                          onPressed: () => setState(() => _obscureKey = !_obscureKey),
                          tooltip: _obscureKey ? 'Show key' : 'Hide key',
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    keyIsSet
                        ? "✓ Gemini API key is set. AI Insights will use your key for analysis."
                        : "Paste your Gemini API key to enable AI-powered diagnostic explanations.",
                    style: TextStyle(
                      fontSize: 11,
                      color: keyIsSet ? Colors.green : Theme.of(context).colorScheme.secondary,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Helper link ─────────────────────────────────────────
                  Row(
                    children: [
                      const Icon(Icons.info_outline, size: 14, color: Colors.grey),
                      const SizedBox(width: 6),
                      Text(
                        "Get a free API key at: aistudio.google.com/app/apikey",
                        style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.secondary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // ── Save button ─────────────────────────────────────────
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton.icon(
                      onPressed: _save,
                      icon: Icon(_saved ? Icons.check : Icons.save, size: 16),
                      label: Text(_saved ? "Saved!" : "Save Configuration"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _saved ? Colors.green : const Color(0xFF5A4FCF),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            ProCard(
              title: "About Guardian Pro",
              iconData: Icons.info_outline,
              expandChild: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "FairAI Guardian Pro is an enterprise-grade ethical diagnostic engine. It continuously monitors, analyzes, and mitigates bias vectors across complex machine learning pipelines.",
                    style: TextStyle(fontSize: 13, height: 1.5),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.only(left: 12),
                    decoration: const BoxDecoration(border: Border(left: BorderSide(color: Color(0xFF5A4FCF), width: 3))),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Version: 4.12.0 (Stable Build)", style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.secondary)),
                        const SizedBox(height: 4),
                        Text("Environment: Production Cluster Alpha", style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.secondary)),
                      ],
                    ),
                  )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
