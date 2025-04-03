import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Task Manager',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: AuthScreen(),
    );
  }
}
//authentication UI 
class AuthScreen extends StatefulWidget {
  @override
  _AuthScreenState createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  User? _user;

  @override
  void initState() {
    super.initState();
    _auth.authStateChanges().listen((User? user) {
      setState(() {
        _user = user;
      });
    });
  }

  void _signInAnonymously() async {
    await _auth.signInAnonymously();
  }

  void _signOut() async {
    await _auth.signOut();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Task Manager")),
      body: _user == null
          ? Center(
              child: ElevatedButton(
                onPressed: _signInAnonymously,
                child: Text("Sign in Anonymously"),
              ),
            )
          : TaskListScreen(user: _user!, signOut: _signOut),
    );
  }
}

class TaskListScreen extends StatefulWidget {
  final User user;
  final VoidCallback signOut;
  TaskListScreen({required this.user, required this.signOut});

  @override
  _TaskListScreenState createState() => _TaskListScreenState();
}

class _TaskListScreenState extends State<TaskListScreen> {
  final TextEditingController _taskController = TextEditingController();
  final CollectionReference tasksCollection =
      FirebaseFirestore.instance.collection('tasks');

  void _addTask() {
    if (_taskController.text.isNotEmpty) {
      tasksCollection.add({
        'userId': widget.user.uid,
        'task': _taskController.text,
        'completed': false,
        'subtasks': []
      });
      _taskController.clear();
    }
  }

  void _toggleTaskCompletion(DocumentSnapshot task) {
    tasksCollection.doc(task.id).update({'completed': !task['completed']});
  }

  void _deleteTask(DocumentSnapshot task) {
    tasksCollection.doc(task.id).delete();
  }

  void _addSubtask(DocumentSnapshot task, String subtask) {
    List subtasks = task['subtasks'];
    subtasks.add(subtask);
    tasksCollection.doc(task.id).update({'subtasks': subtasks});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Task List"),
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: widget.signOut,
          )
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _taskController,
                    decoration: InputDecoration(labelText: "New Task"),
                  ),
                ),
                ElevatedButton(onPressed: _addTask, child: Text("Add"))
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: tasksCollection
                  .where('userId', isEqualTo: widget.user.uid)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return CircularProgressIndicator();
                var tasks = snapshot.data!.docs;
                return ListView.builder(
                  itemCount: tasks.length,
                  itemBuilder: (context, index) {
                    var task = tasks[index];
                    return Card(
                      child: ListTile(
                        title: Text(task['task']),
                        leading: Checkbox(
                          value: task['completed'],
                          onChanged: (_) => _toggleTaskCompletion(task),
                        ),
                        trailing: IconButton(
                          icon: Icon(Icons.delete),
                          onPressed: () => _deleteTask(task),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (String subtask in task['subtasks'])
                              Text("- $subtask"),
                            TextField(
                              onSubmitted: (value) => _addSubtask(task, value),
                              decoration: InputDecoration(
                                hintText: "Add Subtask",
                                border: InputBorder.none,
                              ),
                            )
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}