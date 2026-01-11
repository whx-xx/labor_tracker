import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart'; // 引入强大的日历包
import 'db_helper.dart';

class ProjectDetailPage extends StatefulWidget {
  final int projectId;
  final String projectName;
  final double defaultWage;
  final double dailyHours;
  final double overtimeWage;
  final int overtimeType;
  final double overtimeDivisor;

  const ProjectDetailPage({
    super.key,
    required this.projectId,
    required this.projectName,
    required this.defaultWage,
    required this.dailyHours,
    required this.overtimeWage,
    required this.overtimeType,
    required this.overtimeDivisor,
  });

  @override
  State<ProjectDetailPage> createState() => _ProjectDetailPageState();
}

class _ProjectDetailPageState extends State<ProjectDetailPage> {
  // 使用 Map 来快速查找某一天有没有记录
  Map<DateTime, Map<String, dynamic>> _logsMap = {};
  double _totalIncome = 0.0;
  double _totalGong = 0.0;
  
  // 日历相关状态
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  CalendarFormat _calendarFormat = CalendarFormat.month;

  @override
  void initState() {
    super.initState();
    _refreshLogs();
  }

  void _refreshLogs() async {
    final logs = await DBHelper().getLogsByProject(widget.projectId);
    double totalMoney = 0;
    double totalGong = 0;
    Map<DateTime, Map<String, dynamic>> newMap = {};

    for (var log in logs) {
      totalMoney += (log['total_money'] as num).toDouble();
      
      double regular = (log['regular_hours'] as num).toDouble();
      double overtime = (log['overtime_hours'] as num).toDouble();
      double standard = widget.dailyHours > 0 ? widget.dailyHours : 9.0;
      
      double normalGong = regular / standard;
      double extraGong = 0;
      if (widget.overtimeType == 1 && widget.overtimeDivisor > 0) {
        extraGong = overtime / widget.overtimeDivisor;
      }
      totalGong += (normalGong + extraGong);

      // 将记录存入 Map，Key 是 DateTime (只保留年月日)
      DateTime date = DateTime.parse(log['date']);
      DateTime dateKey = DateTime(date.year, date.month, date.day);
      newMap[dateKey] = log;
    }

    setState(() {
      _logsMap = newMap;
      _totalIncome = totalMoney;
      _totalGong = totalGong;
    });
  }

  // 计算金额逻辑
  double _calculateMoney(double regular, double overtime) {
    double standard = widget.dailyHours > 0 ? widget.dailyHours : 9.0;
    double dayWage = widget.defaultWage;
    double regularMoney = (regular / standard) * dayWage;
    double overtimeMoney = 0.0;
    if (widget.overtimeType == 0) {
      overtimeMoney = overtime * widget.overtimeWage;
    } else {
      if (widget.overtimeDivisor > 0) {
        double extraGong = overtime / widget.overtimeDivisor;
        overtimeMoney = extraGong * dayWage;
      }
    }
    return regularMoney + overtimeMoney;
  }

  void _showLogDialog({Map<String, dynamic>? existingLog, DateTime? targetDate}) {
    final isEditing = existingLog != null;
    DateTime dialogDate = targetDate ?? (isEditing ? DateTime.parse(existingLog['date']) : _selectedDay);

    final regularController = TextEditingController(
      text: isEditing ? existingLog['regular_hours'].toString() : widget.dailyHours.toString(), 
    );
    final overtimeController = TextEditingController(
      text: isEditing ? existingLog['overtime_hours'].toString() : '',
    );
    final moneyController = TextEditingController(
      text: isEditing ? existingLog['total_money'].toString() : '',
    );
    final noteController = TextEditingController(
      text: isEditing ? existingLog['note'] : '',
    );

    if (!isEditing) {
       double initialMoney = _calculateMoney(widget.dailyHours, 0);
       moneyController.text = initialMoney.toStringAsFixed(1);
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent, // 背景透明，为了做圆角
      builder: (ctx) => StatefulBuilder( 
        builder: (context, setModalState) {
          void recalculate() {
            double r = double.tryParse(regularController.text) ?? 0;
            double o = double.tryParse(overtimeController.text) ?? 0;
            double m = _calculateMoney(r, o);
            setModalState(() {
              moneyController.text = m.toStringAsFixed(1);
            });
          }

          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              left: 20, right: 20, top: 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 顶部把手
                Center(child: Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)))),
                const SizedBox(height: 20),
                
                // 标题栏
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(isEditing ? "修改记录" : "记一笔", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.indigo)),
                        const SizedBox(height: 4),
                        Text(DateFormat('yyyy年MM月dd日  EEEE', 'zh_CN').format(dialogDate), style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                      ],
                    ),
                    if (isEditing)
                      IconButton(
                        onPressed: () async {
                          await DBHelper().deleteWorkLog(existingLog['id']);
                          _refreshLogs();
                          if (mounted) Navigator.pop(ctx);
                        },
                        icon: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: Colors.red.shade50, shape: BoxShape.circle),
                          child: const Icon(Icons.delete, color: Colors.red, size: 20)
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 25),

                // 输入区域
                Row(
                  children: [
                    Expanded(child: _buildInputBox("正常班", regularController, recalculate)),
                    const SizedBox(width: 15),
                    Expanded(child: _buildInputBox("加班", overtimeController, recalculate, isHighlight: true)),
                  ],
                ),
                const SizedBox(height: 15),
                _buildMoneyBox(moneyController),
                const SizedBox(height: 15),
                TextField(
                  controller: noteController,
                  decoration: InputDecoration(
                    labelText: '备注 (可选)',
                    prefixIcon: const Icon(Icons.note_alt_outlined),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 25),

                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (moneyController.text.isNotEmpty) {
                        double r = double.tryParse(regularController.text) ?? 0;
                        double o = double.tryParse(overtimeController.text) ?? 0;
                        double money = double.tryParse(moneyController.text) ?? 0;

                        // 未来日期检查
                        final now = DateTime.now();
                        final today = DateTime(now.year, now.month, now.day);
                        final selectDay = DateTime(dialogDate.year, dialogDate.month, dialogDate.day);

                        if (selectDay.isAfter(today)) {
                          bool? continueSave = await showDialog<bool>(
                            context: context,
                            builder: (alertCtx) => AlertDialog(
                              title: const Text("日期提示"),
                              content: const Text("您选择了未来的日期，确定要记录吗？"),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(alertCtx, false), child: const Text("取消")),
                                TextButton(onPressed: () => Navigator.pop(alertCtx, true), child: const Text("确定")),
                              ],
                            ),
                          );
                          if (continueSave != true) return;
                        }

                        if (isEditing) {
                          await DBHelper().updateWorkLog(existingLog['id'], dialogDate, r, o, money, noteController.text);
                          _refreshLogs();
                          if (mounted) Navigator.pop(ctx);
                        } else {
                          int result = await DBHelper().addWorkLog(widget.projectId, dialogDate, r, o, money, noteController.text);
                          if (result == -1) {
                            if (mounted) {
                              showDialog(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text("重复记录", style: TextStyle(color: Colors.red)),
                                  content: const Text("这一天已经有记录了。\n如需修改，请直接点击日历上的日期。"),
                                  actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("知道了"))],
                                ),
                              );
                            }
                          } else {
                            _refreshLogs();
                            if (mounted) Navigator.pop(ctx);
                          }
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 2,
                    ),
                    child: const Text("保存记录", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                )
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildInputBox(String label, TextEditingController ctrl, Function() onChanged, {bool isHighlight = false}) {
    return TextField(
      controller: ctrl,
      keyboardType: TextInputType.number,
      onChanged: (_) => onChanged(),
      decoration: InputDecoration(
        labelText: label,
        suffixText: 'h',
        filled: true,
        fillColor: isHighlight ? Colors.orange.shade50 : Colors.grey.shade50,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: isHighlight ? Colors.orange.shade100 : Colors.transparent),
        ),
      ),
    );
  }

  Widget _buildMoneyBox(TextEditingController ctrl) {
    return TextField(
      controller: ctrl,
      keyboardType: TextInputType.number,
      style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 18),
      decoration: InputDecoration(
        labelText: '当日总收入',
        prefixText: '¥ ',
        filled: true,
        fillColor: Colors.green.shade50,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.green.shade100),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.projectName)),
      body: Column(
        children: [
          // 1. 顶部统计卡片
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.indigo,
              boxShadow: [BoxShadow(color: Colors.indigo.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5))],
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(25)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildHeaderStat("累计收入", "¥${_totalIncome.toStringAsFixed(0)}", Colors.white),
                Container(width: 1, height: 40, color: Colors.white24),
                _buildHeaderStat("累计工数", "${_totalGong.toStringAsFixed(1)}个", Colors.greenAccent),
              ],
            ),
          ),
          
          const SizedBox(height: 10),

          // 2. 超级日历
          Expanded(
            child: TableCalendar(
              locale: 'zh_CN',
              firstDay: DateTime(2020, 1, 1),
              lastDay: DateTime(2030, 12, 31),
              focusedDay: _focusedDay,
              currentDay: DateTime.now(),
              calendarFormat: _calendarFormat,
              headerStyle: const HeaderStyle(
                formatButtonVisible: false,
                titleCentered: true,
                titleTextStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              // 自定义日历格子的高度，让它能容纳下两行文字
              rowHeight: 75, 
              
              // 点击选中逻辑
              selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
              onDaySelected: (selectedDay, focusedDay) {
                setState(() {
                  _selectedDay = selectedDay;
                  _focusedDay = focusedDay;
                });
                // 检查这天有没有数据
                DateTime dateKey = DateTime(selectedDay.year, selectedDay.month, selectedDay.day);
                if (_logsMap.containsKey(dateKey)) {
                  // 有记录：直接打开编辑弹窗
                  _showLogDialog(existingLog: _logsMap[dateKey]);
                } else {
                  // 无记录：直接打开新建弹窗
                  _showLogDialog(targetDate: selectedDay);
                }
              },
              onPageChanged: (focusedDay) => _focusedDay = focusedDay,

              // 核心：自定义构建器，把数据画在格子里
              calendarBuilders: CalendarBuilders(
                // 默认格子的样式
                defaultBuilder: (context, day, focusedDay) => _buildCustomCell(day),
                // 今天格子的样式
                todayBuilder: (context, day, focusedDay) => _buildCustomCell(day, isToday: true),
                // 选中格子的样式
                selectedBuilder: (context, day, focusedDay) => _buildCustomCell(day, isSelected: true),
                // 禁用的格子（上个月/下个月）
                outsideBuilder: (context, day, focusedDay) => const SizedBox.shrink(), 
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 构建一个日历格子
  Widget _buildCustomCell(DateTime day, {bool isToday = false, bool isSelected = false}) {
    // 查数据
    DateTime dateKey = DateTime(day.year, day.month, day.day);
    Map<String, dynamic>? log = _logsMap[dateKey];

    bool hasData = log != null;
    double hours = hasData ? (log['hours'] as num).toDouble() : 0;
    
    // 颜色逻辑
    Color textColor = Colors.black87;
    Color bgColor = Colors.transparent;
    
    if (isSelected) {
      bgColor = Colors.indigo;
      textColor = Colors.white;
    } else if (isToday) {
      bgColor = Colors.indigo.shade50;
      textColor = Colors.indigo;
    }

    return Container(
      margin: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: isToday && !isSelected ? Border.all(color: Colors.indigo, width: 1.5) : null,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 日期数字
          Text(
            '${day.day}',
            style: TextStyle(
              fontSize: 16, 
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          const SizedBox(height: 4),
          
          // 下方紧贴的数据
          if (hasData) 
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected ? Colors.white.withOpacity(0.2) : Colors.green.shade50,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '${hours}h', // 显示工时
                style: TextStyle(
                  fontSize: 11, 
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : Colors.green.shade700,
                ),
              ),
            )
          else
            // 占位符，保持对齐
            const SizedBox(height: 18),
        ],
      ),
    );
  }

  Widget _buildHeaderStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(color: color, fontSize: 24, fontWeight: FontWeight.bold)),
      ],
    );
  }
}