import 'package:flutter/material.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
import 'dart:async';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final keyApplicationId = 'RjcBqpfBb5z2EIacAvlJIVbgAccf47KaIE4hDNeL';
  final keyClientKey = 'sHQZivUJTmie5wmcw3dBE2vUQULkGFgku7oSB3qT';
  final keyParseServerUrl = 'https://parseapi.back4app.com';

  await Parse().initialize(keyApplicationId, keyParseServerUrl,
      clientKey: keyClientKey, debug: true);
  
  runApp(MaterialApp(
    home: Home(),
  ));
}

class Home extends StatefulWidget {
  @override
  _HomeState createState() => _HomeState();
}

class _HomeState extends State<Home> {
  final todoController = TextEditingController();
  Map<String, bool> editModeMap = {};
  ScrollController _scrollController = ScrollController();
  List<ParseObject> todoList = [];
  int _currentPage = 5;
  int _pageSize = 5; // Adjust the page size as needed
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_scrollListener);
    _loadTodo();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollListener() {
    if (!_loading && _scrollController.position.pixels == _scrollController.position.maxScrollExtent) {
      // Reached the end of the list, load more data
      _loadTodo();
    }
  }

  Future<void> _loadTodo() async {
    setState(() {
      _loading = true;
    });

    QueryBuilder<ParseObject> queryTodo = QueryBuilder<ParseObject>(ParseObject('Todo'))
      ..setAmountToSkip(_currentPage * _pageSize)
      ..setLimit(_pageSize);

    final ParseResponse apiResponse = await queryTodo.query();

    if (apiResponse.success && apiResponse.results != null) {
      setState(() {
        todoList.addAll(apiResponse.results as List<ParseObject>);
        _currentPage++;
        _loading = false;
      });
    } else {
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Assignment",
          style: TextStyle(
            color: Colors.white,
          ),
        ),
        backgroundColor: Color(0xFF0699ba),
        centerTitle: true,
      ),
      body: Column(
        children: <Widget>[
          _buildAddTodoWidget(),
          _buildTodoListWidget(),
        ],
      ),
    );
  }

  Widget _buildAddTodoWidget() {
    return Container(
      padding: EdgeInsets.all(16.0),
      child: Row(
        children: <Widget>[
          Expanded(
            child: TextField(
              autocorrect: true,
              textCapitalization: TextCapitalization.sentences,
              controller: todoController,
              decoration: InputDecoration(
                hintText: "Enter your name",
              ),
            ),
          ),
          SizedBox(width: 16.0),
          ElevatedButton(
            onPressed: _addToDo,
            child: Text("ADD"),
          ),
        ],
      ),
    );
  }

  Widget _buildTodoListWidget() {
    return Expanded(
      child: FutureBuilder<List<ParseObject>>(
        future: _getTodo(),
        builder: (context, snapshot) {
          switch (snapshot.connectionState) {
            case ConnectionState.none:
            case ConnectionState.waiting:
              return Center(
                child: CircularProgressIndicator(),
              );
            default:
              if (snapshot.hasError) {
                return Center(
                  child: Text("Error..."),
                );
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return Center(
                  child: Text("No Data..."),
                );
              } else {
                return _buildTodoListView(snapshot.data!);
              }
          }
        },
      ),
    );
  }

  Widget _buildTodoListView(List<ParseObject> todoList) {
    return ListView.builder(
      padding: EdgeInsets.all(16.0),
      itemCount: todoList.length,
      itemBuilder: (context, index) {
        final todo = todoList[index];
        final title = todo.get<String>('title')!;
        final done = todo.get<bool>('done')!;
        bool isEditMode = editModeMap[title] ?? false;

        return Card(
          elevation: 2.0,
          margin: EdgeInsets.symmetric(vertical: 8.0),
          child: ListTile(
            title: isEditMode
                ? TextField(
                    controller: todoController,
                    decoration: InputDecoration(
                      hintText: "Enter your name",
                    ),
                  )
                : Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16.0,
                      color: done ? Colors.green : Colors.black,
                    ),
                  ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Checkbox(
                  value: done,
                  onChanged: (value) async {
                    await _updateTodo(todo.objectId!, value!);
                    setState(() {});
                  },
                ),
                IconButton(
                  icon: Icon(
                    Icons.edit,
                    color: Colors.blue,
                  ),
                  onPressed: () {
                    _showEditDialog(context, title, todo.objectId!);
                  },
                ),
                IconButton(
                  icon: Icon(
                    Icons.delete,
                    color: Colors.red,
                  ),
                  onPressed: () async {
                    await _deleteTodo(todo.objectId!);
                    setState(() {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text("Name deleted successfully!"),
                          duration: Duration(seconds: 2),
                          backgroundColor: Colors.red,
                        ),
                      );
                    });
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showEditDialog(BuildContext context, String currentTitle, String objectId) {
    todoController.text = currentTitle;
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Edit name"),
          content: TextField(
            controller: todoController,
            decoration: InputDecoration(
              hintText: "Update your name",
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text("Cancel"),
            ),
            TextButton(
              onPressed: () async {
                await _updateTodoTitle(objectId, todoController.text);
                setState(() {
                  String updatedName = todoController.text;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text("Your name: $updatedName Updated successufully!"),
                      duration: Duration(seconds: 2),
                      backgroundColor: Colors.orange,
                    ),
                  );
                });
                Navigator.of(context).pop();
              },
              child: Text("Save"),
            ),
          ],
        );
      },
    );
  }

  Future<void> _updateTodoTitle(String id, String newTitle) async {
    var todo = ParseObject('Todo')
      ..objectId = id
      ..set('title', newTitle);
    await todo.save();
  }

  void _addToDo() async {
    if (todoController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Empty title"),
          duration: Duration(seconds: 2),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    String todoTitle = todoController.text;

    await _saveTodo(todoTitle);

    setState(() {
      todoController.clear();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Name $todoTitle added successfully"),
        duration: Duration(seconds: 2),
        backgroundColor: Colors.green,
      ),
    );
    setState(() {});
  }

  Future<void> _saveTodo(String title) async {
    final todo = ParseObject('Todo')..set('title', title)..set('done', false);
    await todo.save();
  }

  Future<List<ParseObject>> _getTodo() async {
    QueryBuilder<ParseObject> queryTodo =
        QueryBuilder<ParseObject>(ParseObject('Todo'));
    final ParseResponse apiResponse = await queryTodo.query();

    if (apiResponse.success && apiResponse.results != null) {
      return apiResponse.results as List<ParseObject>;
    } else {
      return [];
    }
  }

  Future<void> _updateTodo(String id, bool done) async {
    var todo = ParseObject('Todo')
      ..objectId = id
      ..set('done', done);
    await todo.save();
  }

  Future<String> _deleteTodo(String id) async {
    var todo = ParseObject('Todo')..objectId = id;
    String deletedTitle = todo.get<String>('title') ?? '';
    await todo.delete();
    return deletedTitle;
  }
}
