import 'dart:developer';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../api/apis.dart';
import '../helper/dialogs.dart';
import '../main.dart';
import '../models/chat_user.dart';
import '../widgets/chat_user_card.dart';
import 'profile_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

//home screen -- where all available contacts are shown
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<ChatUser> _list = [];
  final List<ChatUser> _searchList = [];
  bool _isSearching = false;
  bool isMentor = false;
  Map<String, dynamic> user = {};
  bool flag = false;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  // Separate method to initialize data asynchronously
  Future<void> _initializeData() async {
    isMentor = await APIs.getSelfInfo() as bool;
    user = (await APIs.getUserById(APIs.me.id))!;
    setState(() {
      flag = true;
    });
    SystemChannels.lifecycle.setMessageHandler((message) {
      log('Message: $message');
      if (APIs.auth.currentUser != null) {
        if (message.toString().contains('resume')) {
          APIs.updateActiveStatus(true);
        }
        if (message.toString().contains('pause')) {
          APIs.updateActiveStatus(false);
        }
      }

      return Future.value(message);
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      //for hiding keyboard when a tap is detected on screen
      onTap: () => FocusScope.of(context).unfocus(),
      child: WillPopScope(
        //if search is on & back button is pressed then close search
        //or else simple close current screen on back button click`
        onWillPop: () {
          if (_isSearching) {
            setState(() {
              _isSearching = !_isSearching;
            });
            return Future.value(false);
          } else {
            return Future.value(true);
          }
        },
        child: Scaffold(
          //app bar
          appBar: AppBar(
            leading: const Icon(CupertinoIcons.home),
            title: _isSearching
                ? TextField(
                    decoration: const InputDecoration(
                        border: InputBorder.none, hintText: 'Name, Email, ...'),
                    autofocus: true,
                    style: const TextStyle(fontSize: 17, letterSpacing: 0.5),
                    //when search text changes then updated search list
                    onChanged: (val) {
                      //search logic
                      _searchList.clear();

                      for (var i in _list) {
                        if (i.name.toLowerCase().contains(val.toLowerCase()) ||
                            i.email.toLowerCase().contains(val.toLowerCase())) {
                          _searchList.add(i);
                          setState(() {
                            _searchList;
                          });
                        }
                      }
                    },
                  )
                : const Text('Mentor Connect'),
            actions: [
              //search user button
              IconButton(
                  onPressed: () {
                    setState(() {
                      _isSearching = !_isSearching;
                    });
                  },
                  icon: Icon(_isSearching
                      ? CupertinoIcons.clear_circled_solid
                      : Icons.search)),

              //more features button
              IconButton(
                  onPressed: () {
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => ProfileScreen(user: APIs.me)));
                  },
                  icon: const Icon(Icons.more_vert))
            ],
          ),

          //floating button to add new user

          floatingActionButton: Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: FloatingActionButton(
                onPressed: () {
                  _addChatUserDialog(context);
                },
                child: const Icon(Icons.add_comment_rounded)),
          ),

          //body
          body: !flag
              ? const Center(child: CircularProgressIndicator())
              : CustomScrollView(
                  slivers: [
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (BuildContext context, int index) {
                          return Column(
                            children: [
                              StreamBuilder(
                                stream: APIs.getMyUsersId(),
                                builder: (context, snapshot) {
                                  switch (snapshot.connectionState) {
                                    case ConnectionState.waiting:
                                    case ConnectionState.none:
                                      return const Center(
                                          child: CircularProgressIndicator());
                                    case ConnectionState.active:
                                    case ConnectionState.done:
                                      return StreamBuilder(
                                        stream: APIs.getAllUsers(
                                          snapshot.data?.docs
                                                  .map((e) => e.id)
                                                  .toList() ??
                                              [],
                                        ),
                                        builder: (context, snapshot) {
                                          switch (snapshot.connectionState) {
                                            case ConnectionState.waiting:
                                            case ConnectionState.none:
                                              // Return a loading indicator or an empty container
                                              return const SizedBox.shrink();

                                            case ConnectionState.active:
                                            case ConnectionState.done:
                                              final data = snapshot.data?.docs;
                                              _list = data
                                                      ?.map((e) =>
                                                          ChatUser.fromJson(
                                                              e.data()))
                                                      .toList() ??
                                                  [];

                                              if (_list.isNotEmpty) {
                                                return ListView.builder(
                                                  shrinkWrap: true,
                                                  physics:
                                                      const BouncingScrollPhysics(),
                                                  itemCount: _isSearching
                                                      ? _searchList.length
                                                      : _list.length,
                                                  itemBuilder:
                                                      (context, index) {
                                                    return ChatUserCard(
                                                      user: _isSearching
                                                          ? _searchList[index]
                                                          : _list[index],
                                                    );
                                                  },
                                                );
                                              } else {
                                                return const Center(
                                                  child: Text(
                                                    'No Connections Found!',
                                                    style:
                                                        TextStyle(fontSize: 20),
                                                  ),
                                                );
                                              }
                                          }
                                        },
                                      );
                                  }
                                },
                              ),
                              // Your button goes here
                              !user['is_mentor'] && !user['is_mentor_assigned']
                                  ? ElevatedButton(
                                      onPressed: () {
                                        log("button pressed");
                                        _loadMentorsList();
                                      },
                                      child: Text('Need a Mentor'),
                                    )
                                  : Container(),
                            ],
                          );
                        },
                        childCount: 1,
                      ),
                    ),
                  ],
                ),
        ),
      ),
      // ),
    );
  }

  void _getAllUsers() {
    APIs.getMyUsersId().listen((QuerySnapshot<Map<String, dynamic>> snapshot) {
      final userIds = snapshot.docs.map((doc) => doc.id).toList();

      if (userIds.isNotEmpty) {
        APIs.getAllUsers(userIds)
            .listen((QuerySnapshot<Map<String, dynamic>> snapshot) {
          final users = snapshot.docs
              .map((doc) => ChatUser.fromJson(doc.data()))
              .toList();

          print('All Users:');
          for (var user in users) {
            print(
                'User ID: ${user.id}, Name: ${user.name}, Email: ${user.email}');
            // Add other properties as needed
          }
        });
      } else {
        print('No users found.');
      }
    });
  }

  void _getAllMentors() {
    APIs.getMentors().listen((QuerySnapshot<Map<String, dynamic>> snapshot) {
      final mentors =
          snapshot.docs.map((doc) => ChatUser.fromJson(doc.data())).toList();

      if (mentors.isNotEmpty) {
        print('All Mentors:');
        for (var mentor in mentors) {
          print(
              'Mentor ID: ${mentor.id}, Name: ${mentor.name}, Email: ${mentor.email}');
          // Add other properties as needed
        }
      } else {
        print('No mentors found.');
      }
    });
  }

  // new

  void _loadMentorsList() {
    List<ChatUser> mentorsList = [];
    // Call the function to get mentors from the database
    APIs.getMentors().listen((snapshot) {
      setState(() {
        // Clear the existing list and add the mentors from the snapshot
        mentorsList =
            snapshot.docs.map((doc) => ChatUser.fromJson(doc.data())).toList();
      });

      // Show the dropdown with the mentors list
      print(mentorsList.length);
      _showMentorsDropdown(mentorsList);
    });
  }

  void _showMentorsDropdown(List<ChatUser> mentorsList) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Select a Mentor'),
          content: DropdownButton(
            items: mentorsList
                .map((mentor) => DropdownMenuItem(
                      value: mentor,
                      child:
                          Text(mentor.name), // Adjust based on your user model
                    ))
                .toList(),
            onChanged: (selectedMentor) async {
              // Handle the selected mentor
              if (selectedMentor!.email.isNotEmpty) {
                await APIs.addChatUser(selectedMentor.email).then((value) {
                  print(selectedMentor.email);
                  if (!value) {
                    Dialogs.showSnackbar(context, 'User does not Exists!');
                  }
                });
              }
              await APIs.updateIsMentorAssigned(APIs.me.id);
              Navigator.pop(context); // Close the dialog
            },
            value: null, // Set the initially selected mentor if needed
          ),
        );
      },
    );
  }
}

//new
// for adding new chat user
void _addChatUserDialog(context) {
  String email = '';

  showDialog(
      context: context,
      builder: (_) => AlertDialog(
            contentPadding:
                const EdgeInsets.only(left: 24, right: 24, top: 20, bottom: 10),

            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),

            //title
            title: Row(
              children: const [
                Icon(
                  Icons.person_add,
                  color: Colors.blue,
                  size: 28,
                ),
                Text('  Add User')
              ],
            ),

            //content
            content: TextFormField(
              maxLines: null,
              onChanged: (value) => email = value,
              decoration: InputDecoration(
                  hintText: 'Email Id',
                  prefixIcon: const Icon(Icons.email, color: Colors.blue),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15))),
            ),

            //actions
            actions: [
              //cancel button
              MaterialButton(
                  onPressed: () {
                    //hide alert dialog
                    Navigator.pop(context);
                  },
                  child: const Text('Cancel',
                      style: TextStyle(color: Colors.blue, fontSize: 16))),

              //add button
              MaterialButton(
                  onPressed: () async {
                    //hide alert dialog
                    Navigator.pop(context);
                    if (email.isNotEmpty) {
                      await APIs.addChatUser(email).then((value) {
                        if (!value) {
                          Dialogs.showSnackbar(
                              context, 'User does not Exists!');
                        }
                      });
                    }
                  },
                  child: const Text(
                    'Add',
                    style: TextStyle(color: Colors.blue, fontSize: 16),
                  ))
            ],
          ));
}
