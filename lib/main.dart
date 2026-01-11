import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'db_helper.dart';
import 'project_detail_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '工时记账',
      debugShowCheckedModeBanner: false, // 去掉右上角Debug标签
      theme: ThemeData(
        primarySwatch: Colors.indigo, // 更沉稳的靛蓝色
        scaffoldBackgroundColor: const Color(0xFFF5F7FA), // 浅灰背景，保护眼睛
        useMaterial3: false,
        appBarTheme: const AppBarTheme(
          elevation: 0,
          centerTitle: true,
          backgroundColor: Colors.indigo,
          foregroundColor: Colors.white,
        ),
      ),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('zh', 'CN'),
      ],
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<Map<String, dynamic>> _projects = [];

  @override
  void initState() {
    super.initState();
    _refreshProjects();
  }

  void _refreshProjects() async {
    final data = await DBHelper().getProjects();
    setState(() {
      _projects = data;
    });
  }

  // 参数 existingProject: 如果是修改，传这个项目对象；如果是新建，传 null
  void _showProjectDialog({Map<String, dynamic>? existingProject}) {
    final isEditing = existingProject != null;
    
    final nameController = TextEditingController(text: isEditing ? existingProject['name'] : '');
    final wageController = TextEditingController(text: isEditing ? existingProject['default_wage'].toString() : '');
    final dailyHoursController = TextEditingController(text: isEditing ? (existingProject['daily_hours']?.toString() ?? '9') : '9');
    final overtimeWageController = TextEditingController(text: isEditing ? (existingProject['overtime_wage']?.toString() ?? '0') : '0');
    final overtimeDivisorController = TextEditingController(text: isEditing ? (existingProject['overtime_divisor']?.toString() ?? '4') : '4');

    int currentOtType = isEditing ? (existingProject['overtime_type'] ?? 0) : 0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
            ),
            padding: EdgeInsets.only(
              top: 25, left: 20, right: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(isEditing ? '修改项目' : '新建工地项目', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.indigo)),
                      IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close, color: Colors.grey)),
                    ],
                  ),
                  const SizedBox(height: 20),

                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: '项目名称', hintText: '例如：邯钢二期',
                      prefixIcon: const Icon(Icons.business, color: Colors.indigo),
                      filled: true, fillColor: Colors.grey.shade50,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                    ),
                    autofocus: !isEditing,
                  ),
                  const SizedBox(height: 25),

                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.indigo.shade50.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.indigo.shade100),
                    ),
                    child: Column(
                      children: [
                        const Row(children: [Icon(Icons.monetization_on_outlined, size: 18, color: Colors.indigo), SizedBox(width: 8), Text("标准日薪规则", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo, fontSize: 15))]),
                        const SizedBox(height: 15),
                        Row(
                          children: [
                            Expanded(child: _buildMiniInput(dailyHoursController, "标准工时", "小时")),
                            const Padding(padding: EdgeInsets.symmetric(horizontal: 10), child: Text("=", style: TextStyle(fontSize: 20, color: Colors.grey, fontWeight: FontWeight.bold))),
                            Expanded(child: _buildMiniInput(wageController, "日薪", "元", prefix: "¥")),
                          ],
                        ),
                        const Divider(height: 30),
                        const Row(children: [Icon(Icons.access_time_filled, size: 18, color: Colors.orange), SizedBox(width: 8), Text("加班计算方式", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange, fontSize: 15))]),
                        const SizedBox(height: 10),
                        
                        // 切换按钮
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                          child: Row(
                            children: [
                              Expanded(
                                child: InkWell(
                                  onTap: () => setModalState(() => currentOtType = 0),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    decoration: BoxDecoration(color: currentOtType == 0 ? Colors.orange : Colors.transparent, borderRadius: BorderRadius.circular(10)),
                                    child: Center(child: Text("按时薪 (元/h)", style: TextStyle(color: currentOtType == 0 ? Colors.white : Colors.grey, fontWeight: FontWeight.bold, fontSize: 13))),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: InkWell(
                                  onTap: () => setModalState(() => currentOtType = 1),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    decoration: BoxDecoration(color: currentOtType == 1 ? Colors.orange : Colors.transparent, borderRadius: BorderRadius.circular(10)),
                                    child: Center(child: Text("按折算 (h/工)", style: TextStyle(color: currentOtType == 1 ? Colors.white : Colors.grey, fontWeight: FontWeight.bold, fontSize: 13))),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 15),

                        if (currentOtType == 0)
                          TextField(
                            controller: overtimeWageController, keyboardType: TextInputType.number,
                            decoration: InputDecoration(labelText: '加班每小时工资', prefixText: '¥ ', suffixText: '元 / 小时', filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
                          )
                        else
                          TextField(
                            controller: overtimeDivisorController, keyboardType: TextInputType.number,
                            decoration: InputDecoration(labelText: '加班几小时算1个工', suffixText: '小时 = 1个工', filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),
                  SizedBox(
                    width: double.infinity, height: 55,
                    child: ElevatedButton(
                      onPressed: () async {
                        if (nameController.text.isNotEmpty) {
                          String name = nameController.text;
                          double wage = double.tryParse(wageController.text) ?? 0.0;
                          double dailyHours = double.tryParse(dailyHoursController.text) ?? 0.0;
                          double otWage = double.tryParse(overtimeWageController.text) ?? 0.0;
                          double otDivisor = double.tryParse(overtimeDivisorController.text) ?? 0.0;
                          if (isEditing) {
                            await DBHelper().updateProject(existingProject['id'], name, wage, dailyHours, otWage, currentOtType, otDivisor);
                          } else {
                            await DBHelper().addProject(name, wage, dailyHours, otWage, currentOtType, otDivisor);
                          }
                          _refreshProjects();
                          if (mounted) Navigator.pop(ctx);
                        }
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 4),
                      child: const Text('保 存 项 目', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // 小输入框构建方法
  Widget _buildMiniInput(TextEditingController controller, String label, String suffix, {String? prefix}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
        const SizedBox(height: 5),
        TextField(
          controller: controller, keyboardType: TextInputType.number, textAlign: TextAlign.center,
          decoration: InputDecoration(prefixText: prefix, suffixText: suffix, filled: true, fillColor: Colors.white, contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
        ),
      ],
    );
  }

  void _confirmDelete(int projectId, String projectName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('删除 "$projectName"?'),
        content: const Text('注意：删除项目会一并清空该项目下的所有工时记录，且无法恢复！'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(
            onPressed: () async {
              await DBHelper().deleteProject(projectId);
              _refreshProjects();
              if (mounted) Navigator.pop(ctx);
            },
            child: const Text('确认删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('我的工地项目')),
      body: _projects.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.assignment_add, size: 80, color: Colors.grey.shade300),
                  const SizedBox(height: 10),
                  const Text('还没有项目，点击右下角添加', style: TextStyle(color: Colors.grey, fontSize: 16)),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.only(top: 10, bottom: 80),
              itemCount: _projects.length,
              itemBuilder: (ctx, index) {
                final project = _projects[index];
                return GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ProjectDetailPage(
                          projectId: project['id'], 
                          projectName: project['name'],
                          defaultWage: project['default_wage'],
                          dailyHours: project['daily_hours'] ?? 9.0,
                          overtimeWage: project['overtime_wage'] ?? 0.0,
                          overtimeType: project['overtime_type'] ?? 0,
                          overtimeDivisor: project['overtime_divisor'] ?? 0.0,
                        )
                      ),
                    ).then((_) => _refreshProjects());
                  },
                  onLongPress: () {
                    showModalBottomSheet(
                      context: context,
                      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
                      builder: (ctx) => Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(height: 10),
                          Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10))),
                          const SizedBox(height: 20),
                          ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8)),
                              child: const Icon(Icons.edit, color: Colors.blue),
                            ),
                            title: const Text('修改项目信息', style: TextStyle(fontWeight: FontWeight.bold)),
                            onTap: () {
                              Navigator.pop(ctx);
                              _showProjectDialog(existingProject: project);
                            },
                          ),
                          ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
                              child: const Icon(Icons.delete, color: Colors.red),
                            ),
                            title: const Text('删除该项目', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                            onTap: () {
                              Navigator.pop(ctx);
                              _confirmDelete(project['id'], project['name']);
                            },
                          ),
                          const SizedBox(height: 20),
                        ],
                      ),
                    );
                  },
                  child: Card(
                    elevation: 4, // 阴影深度
                    margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16), // 外边距
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16) // 圆角
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.white, Colors.indigo.shade50.withOpacity(0.3)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16)
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  project['name'],
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.indigo),
                                ),
                                const Icon(Icons.chevron_right, color: Colors.grey),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                _buildInfoChip(Icons.access_time, "标准: ${project['daily_hours'] ?? 9}h"),
                                const SizedBox(width: 8),
                                _buildInfoChip(Icons.monetization_on, "¥${project['default_wage']}/天"),
                              ],
                            )
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showProjectDialog(),
        backgroundColor: Colors.indigo,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.grey),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 13, color: Colors.black87)),
        ],
      ),
    );
  }
}