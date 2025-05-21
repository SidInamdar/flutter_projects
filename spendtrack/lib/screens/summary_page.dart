import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // For date and number formatting
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_charts/charts.dart'; // Syncfusion charts import

// Assuming these models and services are correctly defined in your project
import 'package:spendtrack/models/transaction_model.dart'; // Replace your_app_name
import 'package:spendtrack/db/database_helper.dart';     // Replace your_app_name (Firebase service)
import 'package:spendtrack/services/auth_service.dart';   // Replace your_app_name

// Enum for time filters - REMOVED weekly
enum TimeFilter { daily, monthly, custom }

// Helper class for chart data points
class ChartData {
  ChartData(this.x, this.y, [this.xValue]);
  final dynamic x; // DateTime for line chart's actual X value, String for bar chart's category
  final double y;
  final String? xValue; // Optional: For bar chart display label if x is not the label itself
}

class SummaryPage extends StatefulWidget {
  const SummaryPage({super.key});

  @override
  State<SummaryPage> createState() => _SummaryPageState();
}

class _SummaryPageState extends State<SummaryPage> {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  List<TransactionModel> _allTransactions = [];
  List<TransactionModel> _filteredTransactions = [];
  bool _isLoading = true;
  bool _isProcessingFilters = false;

  TimeFilter _selectedTimeFilter = TimeFilter.monthly;
  Set<String> _availableTags = {};
  Set<String> _selectedTags = {};
  DateTimeRange? _customDateRange;

  List<ChartData> _cumulativeExpenseData = [];
  List<ChartData> _expenseBarData = [];
  double _maxYForBarChart = 0.0;
  double _maxYForCumulativeChart = 0.0; // Added for cumulative chart Y-axis scaling

  TooltipBehavior? _lineChartTooltipBehavior;
  TooltipBehavior? _barChartTooltipBehavior;

  @override
  void initState() {
    super.initState();
    _lineChartTooltipBehavior = TooltipBehavior(
        enable: true,
        header: 'Date',
        builder: (dynamic data, dynamic point, dynamic series, int pointIndex, int seriesIndex) {
          final chartData = data as ChartData;
          return Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.95), borderRadius: BorderRadius.circular(4), boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 2, offset: Offset(0,1))]),
            child: Text(
                '${DateFormat.yMMMd().format(chartData.x as DateTime)}: ${NumberFormat.currency(locale: 'en_IN', name: 'INR', symbol: '₹', decimalDigits: 0).format(chartData.y)}',
                style: const TextStyle(color: Colors.black, fontSize: 12)
            ),
          );
        });
    _barChartTooltipBehavior = TooltipBehavior(
        enable: true,
        header: 'Category',
        builder: (dynamic data, dynamic point, dynamic series, int pointIndex, int seriesIndex) {
          final chartData = data as ChartData;
          return Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.95), borderRadius: BorderRadius.circular(4), boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 2, offset: Offset(0,1))]),
            child: Text(
                '${chartData.x}: ${NumberFormat.currency(locale: 'en_IN', name: 'INR', symbol: '₹', decimalDigits: 0).format(chartData.y)}',
                style: const TextStyle(color: Colors.black, fontSize: 12)
            ),
          );
        });
    _fetchInitialData();
  }

  Future<void> _fetchInitialData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      if (authService.currentUser == null) throw Exception("User not logged in");
      final transactions = await _dbHelper.getAllTransactions();
      if (!mounted) return;
      _allTransactions = transactions.where((t) => t.amount > 0)
          .map((t) => TransactionModel(id: t.id, amount: t.amount, description: t.description, tags: t.tags, date: t.date))
          .toList();
      _extractAvailableTags();
      await _applyFiltersAndProcessData();
    } catch (e, s) {
      print("SummaryPage: Error fetching initial data: $e\n$s");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error loading summary: ${e.toString()}"), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _extractAvailableTags() {
    final tags = <String>{};
    for (var transaction in _allTransactions) {
      if (transaction.tags.isNotEmpty) {
        transaction.tags.split(',').forEach((tag) {
          final trimmedTag = tag.trim();
          if (trimmedTag.isNotEmpty) tags.add(trimmedTag);
        });
      }
    }
    if (!mounted) return;
    _availableTags = Set.from(tags.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase())));
  }

  DateTimeRange _getDateRangeForFilter(TimeFilter filter, DateTime now) {
    DateTime endOfToday = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
    switch (filter) {
      case TimeFilter.daily:
        return DateTimeRange(start: DateTime(now.year, now.month, now.day).subtract(const Duration(days: 6)), end: endOfToday);
      case TimeFilter.monthly:
      default:
        DateTime firstDayOfCurrentMonth = DateTime(now.year, now.month, 1);
        DateTime startMonth = DateTime(firstDayOfCurrentMonth.year, firstDayOfCurrentMonth.month - 5, 1);
        return DateTimeRange(start: startMonth, end: endOfToday);
    }
  }

  Future<void> _applyFiltersAndProcessData() async {
    if (!mounted) return;
    setState(() => _isProcessingFilters = true);
    await Future.delayed(Duration.zero);

    final now = DateTime.now();
    DateTimeRange activeDateRange = _selectedTimeFilter == TimeFilter.custom && _customDateRange != null
        ? _customDateRange!
        : _getDateRangeForFilter(_selectedTimeFilter, now);

    final inclusiveEndDate = DateTime(activeDateRange.end.year, activeDateRange.end.month, activeDateRange.end.day, 23, 59, 59, 999);

    _filteredTransactions = _allTransactions.where((transaction) {
      final transactionDate = transaction.date;
      bool dateMatch = !transactionDate.isBefore(activeDateRange.start) && !transactionDate.isAfter(inclusiveEndDate);
      bool tagMatch = _selectedTags.isEmpty || _selectedTags.any((selectedTag) =>
          transaction.tags.split(',').map((t) => t.trim().toLowerCase()).contains(selectedTag.toLowerCase()));
      return dateMatch && tagMatch;
    }).toList();

    _filteredTransactions.sort((a,b) => a.date.compareTo(b.date));
    _processDataForChartsLogic();

    if (mounted) setState(() => _isProcessingFilters = false);
  }

  void _processDataForChartsLogic() {
    // 1. Cumulative Expense Data
    List<ChartData> newCumulativeData = [];
    double cumulativeSum = 0;
    double maxCumulativeY = 0;
    Map<DateTime, double> dailyAggregatedAmounts = {};

    for (var transaction in _filteredTransactions) {
      final dayKey = DateTime(transaction.date.year, transaction.date.month, transaction.date.day);
      dailyAggregatedAmounts[dayKey] = (dailyAggregatedAmounts[dayKey] ?? 0) + transaction.amount;
    }

    List<DateTime> sortedDays = dailyAggregatedAmounts.keys.toList()..sort();
    for (DateTime dayKey in sortedDays) {
      cumulativeSum += dailyAggregatedAmounts[dayKey]!;
      newCumulativeData.add(ChartData(dayKey, cumulativeSum));
      if (cumulativeSum > maxCumulativeY) maxCumulativeY = cumulativeSum;
    }
    _cumulativeExpenseData = newCumulativeData;
    _maxYForCumulativeChart = maxCumulativeY == 0 ? 100 : (maxCumulativeY * 1.20); // 20% padding

    print("SummaryPage: Cumulative Data Points for Chart:");
    for (var dataPoint in _cumulativeExpenseData) {
      print(" - X: ${DateFormat.yMd().format(dataPoint.x as DateTime)}, Y: ${dataPoint.y}");
    }


    // 2. Expense Bar Data
    List<ChartData> newBarData = [];
    Map<String, double> barMap = {};
    double newMaxYForBar = 0.0;

    if (_selectedTags.isNotEmpty) {
      List<String> sortedSelectedTags = _selectedTags.toList()..sort((a,b) => a.toLowerCase().compareTo(b.toLowerCase()));
      for (var tag in sortedSelectedTags) barMap[tag] = 0;
      for (var transaction in _filteredTransactions) {
        transaction.tags.split(',').map((t) => t.trim()).forEach((tag) {
          if (_selectedTags.contains(tag)) barMap[tag] = (barMap[tag] ?? 0) + transaction.amount;
        });
      }
      for(var tag in sortedSelectedTags){
        final value = barMap[tag] ?? 0.0;
        newBarData.add(ChartData(tag, value));
        if (value > newMaxYForBar) newMaxYForBar = value;
      }
    } else {
      DateFormat displayFormat;
      Map<DateTime, double> timeAggregatedAmounts = {};
      switch (_selectedTimeFilter) {
        case TimeFilter.daily:
          displayFormat = DateFormat('E, MMM d');
          for (var t in _filteredTransactions) {
            final dayKey = DateTime(t.date.year, t.date.month, t.date.day);
            timeAggregatedAmounts[dayKey] = (timeAggregatedAmounts[dayKey] ?? 0) + t.amount;
          }
          break;
        case TimeFilter.monthly:
        default:
          displayFormat = DateFormat('MMM yy');
          for (var t in _filteredTransactions) {
            final monthKey = DateTime(t.date.year, t.date.month, 1);
            timeAggregatedAmounts[monthKey] = (timeAggregatedAmounts[monthKey] ?? 0) + t.amount;
          }
          break;
      }
      List<DateTime> sortedTimeKeys = timeAggregatedAmounts.keys.toList()..sort();
      for (var timeKey in sortedTimeKeys) {
        final title = displayFormat.format(timeKey);
        final value = timeAggregatedAmounts[timeKey]!;
        newBarData.add(ChartData(title, value));
        if (value > newMaxYForBar) newMaxYForBar = value;
      }
    }
    _expenseBarData = newBarData;
    _maxYForBarChart = newMaxYForBar == 0 ? 100 : (newMaxYForBar * 1.25);
  }

  Widget _buildFilterControls() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Time Period", style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8.0),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: TimeFilter.values.where((filter) => filter != TimeFilter.custom).map((filter) {
                bool isSelected = _selectedTimeFilter == filter;
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: ChoiceChip(
                    label: Text(filter.name[0].toUpperCase() + filter.name.substring(1)),
                    selected: isSelected,
                    onSelected: (bool selected) {
                      if (selected) {
                        setState(() => _selectedTimeFilter = filter);
                        _applyFiltersAndProcessData();
                      }
                    },
                    selectedColor: Theme.of(context).colorScheme.primaryContainer,
                    labelStyle: TextStyle(color: isSelected ? Theme.of(context).colorScheme.onPrimaryContainer : Theme.of(context).textTheme.bodyLarge?.color),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 20.0),
          Text("Filter by Tags", style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8.0),
          _availableTags.isEmpty && !_isLoading
              ? const Padding(padding: EdgeInsets.symmetric(vertical: 8.0), child: Text("No tags found.", style: TextStyle(color: Colors.grey)))
              : Wrap(
            spacing: 8.0, runSpacing: 4.0,
            children: _availableTags.map((tag) {
              bool isSelected = _selectedTags.contains(tag);
              return FilterChip(
                label: Text(tag), selected: isSelected,
                onSelected: (bool selected) {
                  setState(() {
                    if (selected) _selectedTags.add(tag); else _selectedTags.remove(tag);
                  });
                  _applyFiltersAndProcessData();
                },
                selectedColor: Theme.of(context).colorScheme.primaryContainer,
                checkmarkColor: Theme.of(context).colorScheme.onPrimaryContainer,
                labelStyle: TextStyle(color: isSelected ? Theme.of(context).colorScheme.onPrimaryContainer : Theme.of(context).textTheme.bodyLarge?.color),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildCumulativeChart() {
    if (_cumulativeExpenseData.length < 2 && !_isLoading && !_isProcessingFilters) { // Needs at least 2 points
      return Center(
        heightFactor: 5,
        child: Text(_cumulativeExpenseData.isEmpty
            ? "No data for cumulative plot."
            : "Not enough data for trend (needs >1 day). Total: ${NumberFormat.currency(locale: 'en_IN', name: 'INR', symbol: '₹', decimalDigits: 0).format(_cumulativeExpenseData.first.y)}",
            textAlign: TextAlign.center),
      );
    }
    if (_cumulativeExpenseData.isEmpty) return const SizedBox.shrink();


    return SfCartesianChart(
      key: ValueKey('cumulativeChart_$_selectedTimeFilter\_${_selectedTags.join('_')}'),
      plotAreaBorderWidth: 0,
      primaryXAxis: DateTimeAxis(
        // Determine minimum and maximum from the data to ensure the axis fits the data
        minimum: _cumulativeExpenseData.first.x as DateTime,
        maximum: _cumulativeExpenseData.last.x as DateTime,
        dateFormat: _getAxisDateFormat(), // Dynamic date format
        intervalType: _getAxisIntervalType(), // Dynamic interval type
        majorGridLines: const MajorGridLines(width: 0),
        axisLine: const AxisLine(width: 0.7, color: Colors.grey),
        majorTickLines: const MajorTickLines(size: 0), // Hide major ticks
        labelStyle: const TextStyle(color: Colors.black54, fontSize: 10),
        edgeLabelPlacement: EdgeLabelPlacement.shift,
        labelRotation: -45, // Rotate labels to prevent overlap
        interval: _getAxisInterval(), // Calculate interval based on range
      ),
      primaryYAxis: NumericAxis(
        numberFormat: NumberFormat.currency(locale: 'en_IN', name: 'INR', symbol: '₹', decimalDigits: 0),
        majorGridLines: const MajorGridLines(width: 0.5, dashArray: <double>[3, 3], color: Colors.grey),
        axisLine: const AxisLine(width: 0),
        labelStyle: const TextStyle(color: Colors.black54, fontSize: 10),
        minimum: 0, // Always start Y axis at 0 for cumulative
        maximum: _maxYForCumulativeChart, // Use calculated max Y
      ),
      series: <CartesianSeries<ChartData, DateTime>>[
        SplineAreaSeries<ChartData, DateTime>(
          dataSource: _cumulativeExpenseData,
          xValueMapper: (ChartData data, _) => data.x as DateTime,
          yValueMapper: (ChartData data, _) => data.y,
          name: 'Cumulative Expenses',
          color: Theme.of(context).colorScheme.primary.withOpacity(0.15),
          borderColor: Theme.of(context).colorScheme.primary,
          borderWidth: 2, // Ensure line is visible
          animationDuration: 700,
        )
      ],
      tooltipBehavior: _lineChartTooltipBehavior,
      margin: const EdgeInsets.fromLTRB(5, 10, 15, 10), // L,T,R,B
    );
  }

  DateFormat _getAxisDateFormat() {
    if (_cumulativeExpenseData.length < 2) return DateFormat.MMMd();
    final firstDate = _cumulativeExpenseData.first.x as DateTime;
    final lastDate = _cumulativeExpenseData.last.x as DateTime;
    final rangeInDays = lastDate.difference(firstDate).inDays;

    if (rangeInDays <= 1) return DateFormat.jm(); // Time if same day
    if (rangeInDays <= 14) return DateFormat.Md(); //  M/d for up to 2 weeks
    if (rangeInDays <= 70) return DateFormat.MMMd(); // May 20 for up to ~2 months
    return DateFormat.MMM(); // May for longer
  }

  DateTimeIntervalType _getAxisIntervalType() {
    if (_cumulativeExpenseData.length < 2) return DateTimeIntervalType.days;
    final firstDate = _cumulativeExpenseData.first.x as DateTime;
    final lastDate = _cumulativeExpenseData.last.x as DateTime;
    final rangeInDays = lastDate.difference(firstDate).inDays;

    if (rangeInDays <= 1) return DateTimeIntervalType.hours;
    if (rangeInDays <= 35) return DateTimeIntervalType.days; // Up to 5 weeks, show days
    // If DateTimeIntervalType.weeks is problematic, use days with larger interval or months
    // For now, let's try to avoid .weeks if it was the source of the error.
    // if (rangeInDays <= 120) return DateTimeIntervalType.days; // For up to ~4 months, show days with larger interval
    return DateTimeIntervalType.months;
  }

  double? _getAxisInterval() { // Returns interval value, or null for auto
    if (_cumulativeExpenseData.length < 2) return null;
    final firstDate = _cumulativeExpenseData.first.x as DateTime;
    final lastDate = _cumulativeExpenseData.last.x as DateTime;
    final rangeInDays = lastDate.difference(firstDate).inDays.abs();

    if (rangeInDays <= 1) return 6; // Interval of 6 hours if range is 1 day or less
    if (rangeInDays <= 7) return 1; // Interval of 1 day for a week
    if (rangeInDays <= 14) return 2; // Interval of 2 days for two weeks
    if (rangeInDays <= 35) return 7; // Interval of 7 days (1 week) for up to 5 weeks
    // For monthly, Syncfusion's DateTimeIntervalType.months usually handles it well.
    // If we use DateTimeIntervalType.days for longer periods, we might set a larger day interval.
    // if (rangeInDays <= 120) return 15; // Approx. 2 labels per month
    return null; // Let Syncfusion decide for months or if DateTimeIntervalType.auto is used
  }


  Widget _buildExpenseBarChart() {
    if (_expenseBarData.isEmpty) {
      return const Center(heightFactor: 5, child: Text("No data available for the selected filters."));
    }
    return SfCartesianChart(
      key: ValueKey('barChart_$_selectedTimeFilter\_${_selectedTags.join('_')}'),
      plotAreaBorderWidth: 0,
      primaryXAxis: CategoryAxis(
        majorGridLines: const MajorGridLines(width: 0),
        axisLine: const AxisLine(width: 0.7, color: Colors.grey),
        majorTickLines: const MajorTickLines(size: 0),
        labelStyle: const TextStyle(color: Colors.black54, fontSize: 10),
        labelIntersectAction: AxisLabelIntersectAction.rotate45,
        // interval: 1, // Show all labels for CategoryAxis if possible
      ),
      primaryYAxis: NumericAxis(
        numberFormat: NumberFormat.currency(locale: 'en_IN', name: 'INR', symbol: '₹', decimalDigits: 0),
        majorGridLines: const MajorGridLines(width: 0.5, dashArray: <double>[3, 3], color: Colors.grey),
        axisLine: const AxisLine(width: 0),
        labelStyle: const TextStyle(color: Colors.black54, fontSize: 10),
        maximum: _maxYForBarChart > 0 ? _maxYForBarChart : null,
        minimum: 0,
      ),
      series: <CartesianSeries<ChartData, String>>[
        ColumnSeries<ChartData, String>(
          dataSource: _expenseBarData,
          xValueMapper: (ChartData data, _) => data.x as String,
          yValueMapper: (ChartData data, _) => data.y,
          name: 'Expenses',
          color: Theme.of(context).colorScheme.secondary,
          borderRadius: const BorderRadius.all(Radius.circular(3)),
          width: _expenseBarData.length > 5 ? 0.7 : 0.4, // Wider bars for fewer items
          dataLabelSettings: DataLabelSettings(
              isVisible: true,
              labelAlignment: ChartDataLabelAlignment.top,
              textStyle: TextStyle(fontSize: 9, color: Colors.grey[800], fontWeight: FontWeight.w500),
              // Use builder for custom data label format if needed
              builder: (dynamic data, dynamic point, dynamic series, int pointIndex, int seriesIndex) {
                final chartData = data as ChartData;
                return Text(NumberFormat.compact(locale: 'en_IN').format(chartData.y), style: TextStyle(fontSize: 9, color: Colors.grey[800]));
              }
          ),
          animationDuration: 700,
        )
      ],
      tooltipBehavior: _barChartTooltipBehavior,
      margin: const EdgeInsets.fromLTRB(10, 10, 15, 10),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool showChartLoader = _isProcessingFilters && !_isLoading;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transaction Summary'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: (_isLoading || _isProcessingFilters) ? null : _fetchInitialData,
            tooltip: "Refresh Data",
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: _fetchInitialData,
        child: ListView(
          children: <Widget>[
            _buildFilterControls(),
            const Divider(height: 1, thickness: 1),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.fromLTRB(16.0, 10.0, 16.0, 0),
              child: Text("Cumulative Expenses", style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 18)),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4.0), // Reduced padding
              height: 250,
              child: showChartLoader ? const Center(child: CircularProgressIndicator(strokeWidth: 2)) : _buildCumulativeChart(),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.fromLTRB(16.0, 10.0, 16.0, 0),
              child: Text("Expense Bar Plot", style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 18)),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4.0), // Reduced padding
              height: 250,
              child: showChartLoader ? const Center(child: CircularProgressIndicator(strokeWidth: 2)) : _buildExpenseBarChart(),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}
