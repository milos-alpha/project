import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart' as firebase_storage;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final firebase_storage.FirebaseStorage _storage = firebase_storage.FirebaseStorage.instance;

  String? _profileImageUrl;
  String? _userName;
  String? _userEmail;
  bool _isLoading = true;
  final double _activitiesCovered = 65.0; // Example value
  final double _activitiesRemaining = 35.0; // Example value

  // SharedPreferences keys (matching login/signup screens)
  static const String keyUserId = 'user_id';
  static const String keyUsername = 'username';
  static const String keyEmail = 'email';
  static const String keyName = 'name';
  static const String keyIsLoggedIn = 'is_logged_in';
  static const String keyProfileImage = 'profile_image';
  static const String keyLastUpdated = 'last_updated';

  final List<Map<String, String>> _carouselItems = [
    {
      'title': 'Welcome to SchedulePro',
      'description': 'Manage your daily activities efficiently and stay organized.',
    },
    {
      'title': 'Track Your Progress',
      'description': 'Monitor your completed and upcoming activities at a glance.',
    },
    {
      'title': 'Stay Updated',
      'description': 'Get notifications about important events and deadlines.',
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // First try to load from SharedPreferences
      String? userId = prefs.getString(keyUserId);
      String? username = prefs.getString(keyUsername);
      String? email = prefs.getString(keyEmail);
      String? name = prefs.getString(keyName);
      String? profileImage = prefs.getString(keyProfileImage);

      if (userId != null) {
        // Check if we need to refresh from Firestore
        final lastUpdated = prefs.getInt(keyLastUpdated) ?? 0;
        final currentTime = DateTime.now().millisecondsSinceEpoch;
        final shouldRefresh = currentTime - lastUpdated > 3600000; // 1 hour

        if (shouldRefresh) {
          // Refresh data from Firestore
          final userDoc = await _firestore.collection('users').doc(userId).get();

          if (userDoc.exists) {
            final userData = userDoc.data()!;

            // Update SharedPreferences with fresh data
            await prefs.setString(keyUsername, userData['username'] ?? '');
            await prefs.setString(keyEmail, userData['email'] ?? '');
            await prefs.setString(keyName, userData['name'] ?? '');
            await prefs.setInt(keyLastUpdated, currentTime);

            // Update local state
            username = userData['username'];
            email = userData['email'];
            name = userData['name'];
          }
        }

        // Try to get profile image from Firebase Storage
        if (userId.isNotEmpty) {
          try {
            final imageRef = _storage.ref().child('profile_images/$userId.jpg');
            final imageUrl = await imageRef.getDownloadURL();

            // Cache the profile image URL
            await prefs.setString(keyProfileImage, imageUrl);
            profileImage = imageUrl;
          } catch (e) {
            debugPrint('Error loading profile image: $e');
          }
        }
      }

      if (mounted) {
        setState(() {
          _userName = name ?? username ?? 'User';
          _userEmail = email ?? 'email@example.com';
          _profileImageUrl = profileImage;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading user data: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String? _profilePictureUrl; // Store the URL

  Future<void> _updateProfilePicture(BuildContext context) async {
    final ImagePicker picker = ImagePicker();
    XFile? image;

    try {
      // 1. Select Image
      image = await picker.pickImage(source: ImageSource.gallery); // Or ImageSource.camera

      if (image == null) {
        // User cancelled image selection
        return;
      }

      File imageFile = File(image.path);

      // 2. Upload to Firebase Storage
      final userId = FirebaseAuth.instance.currentUser?.uid; // Get user ID (if using Firebase Auth)
      if (userId == null) {
        debugPrint("User not logged in.");
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('You must be logged in to update your profile picture.')));
        return; // Or handle the case where the user isn't logged in
      }

      final storageRef = _storage
          .ref()
          .child('profile_pictures') // Create a folder
          .child('$userId.jpg'); // Use user ID for unique name

      firebase_storage.UploadTask uploadTask = storageRef.putFile(imageFile);

      await uploadTask.whenComplete(() => null); // Wait for upload to complete

      final imageUrl = await storageRef.getDownloadURL();

      // 3. Update Firestore (Optional - if you store the URL in Firestore)
      // Replace with your Firestore collection and document
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .update({'profilePictureUrl': imageUrl});


      // 4. Update SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('profilePictureUrl', imageUrl);
      await prefs.setString(keyProfileImage, imageUrl); //Also store in the correct key

      // 5. Update Local State
      setState(() {
        _profileImageUrl = imageUrl;
      });

      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile picture updated!')));


    } catch (e) {
      debugPrint('Error updating profile picture: $e');
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update profile picture: $e')));
    }
  }

  Future<void> _clearLocalData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
    } catch (e) {
      debugPrint('Error clearing local data: $e');
    }
  }

  void _showActivitiesModal(String title, List<String> activities) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: activities
                .map((activity) => ListTile(
              leading: const Icon(Icons.check_circle),
              title: Text(activity),
            ))
                .toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showReviewDialog() {
    final TextEditingController reviewController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Write a Review'),
        content: TextField(
          controller: reviewController,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Share your experience with the app...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              // TODO: Implement review submission
              Navigator.pop(context);
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).primaryColor,
            Theme.of(context).primaryColor.withOpacity(0.8),
          ],
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => _updateProfilePicture(context),
                child: Hero(
                  tag: 'profile_image',
                  child: CircleAvatar(
                    radius: 30,
                    backgroundImage: _profileImageUrl != null
                        ? NetworkImage(_profileImageUrl!)
                        : null,
                    child: _profileImageUrl == null
                        ? const Icon(Icons.person, size: 30, color: Colors.white)
                        : null,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _userName ?? 'User',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      _userEmail ?? 'email@example.com',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          ElevatedButton(
            onPressed: () => _updateProfilePicture(context),
            child: const Text('Update Profile Picture'),
          ),
        ],
      ),
    );
  }

  Widget _buildCarousel() {
    return CarouselSlider(
      options: CarouselOptions(
        height: 200.0,
        autoPlay: true,
        enlargeCenterPage: true,
      ),
      items: _carouselItems.map((item) {
        return Builder(
          builder: (BuildContext context) {
            return Container(
              width: MediaQuery.of(context).size.width,
              margin: const EdgeInsets.symmetric(horizontal: 5.0),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      item['title']!,
                      style: const TextStyle(
                        fontSize: 20.0,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      item['description']!,
                      style: const TextStyle(fontSize: 16.0),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          },
        );
      }).toList(),
    );
  }

  Widget _buildStatistics() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          Expanded(
            child: _buildStatCard(
              'Activities Covered',
              _activitiesCovered,
              Colors.green,
                  () => _showActivitiesModal(
                'Completed Activities',
                ['Activity 1', 'Activity 2', 'Activity 3'], // Example data
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _buildStatCard(
              'Activities Remaining',
              _activitiesRemaining,
              Colors.orange,
                  () => _showActivitiesModal(
                'Remaining Activities',
                ['Activity 4', 'Activity 5'], // Example data
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
      String title, double percentage, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        elevation: 4,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              CircularProgressIndicator(
                value: percentage / 100,
                color: color,
              ),
              const SizedBox(height: 8),
              Text(
                '${percentage.toStringAsFixed(1)}%',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReviewButton() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Card(
        elevation: 4,
        child: InkWell(
          onTap: _showReviewDialog,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.rate_review),
                SizedBox(width: 8),
                Text(
                  'Write a Review',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 16),
          _buildCarousel(),
          const SizedBox(height: 16),
          _buildStatistics(),
          _buildReviewButton(),
        ],
      ),
    );
  }
}
