import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// -----------------------------------------------------------------------------
// 1. DOMAIN MODELS
// -----------------------------------------------------------------------------

enum DownloadStatus { notDownloaded, queued, downloading, completed, failed }

class Track {
  final String id;
  final String title;
  final String artistName;
  final String albumTitle;
  final String artworkUrl;
  final String audioUrl;
  final int durationSeconds;
  final bool downloadable;

  const Track({
    required this.id,
    required this.title,
    required this.artistName,
    required this.albumTitle,
    required this.artworkUrl,
    required this.audioUrl,
    required this.durationSeconds,
    this.downloadable = true,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'artistName': artistName,
        'albumTitle': albumTitle,
        'artworkUrl': artworkUrl,
        'audioUrl': audioUrl,
        'durationSeconds': durationSeconds,
        'downloadable': downloadable,
      };

  factory Track.fromJson(Map<String, dynamic> json) => Track(
        id: json['id'],
        title: json['title'],
        artistName: json['artistName'],
        albumTitle: json['albumTitle'],
        artworkUrl: json['artworkUrl'],
        audioUrl: json['audioUrl'],
        durationSeconds: json['durationSeconds'],
        downloadable: json['downloadable'] ?? true,
      );
}

class Playlist {
  final String id;
  final String name;
  final String description;
  final List<Track> tracks;

  const Playlist({
    required this.id,
    required this.name,
    required this.description,
    required this.tracks,
  });
}

// -----------------------------------------------------------------------------
// 2. SAMPLE CATALOG DATA
// -----------------------------------------------------------------------------

final List<Track> kSampleTracks = [
  const Track(
    id: 't1',
    title: 'Midnight Resonance',
    artistName: 'Aura',
    albumTitle: 'Synthetics',
    artworkUrl:
        'https://images.unsplash.com/photo-1614613535308-eb5fbd3d2c17?w=500&q=80',
    audioUrl: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3',
    durationSeconds: 372,
  ),
  const Track(
    id: 't2',
    title: 'Neon Horizon',
    artistName: 'CyberEcho',
    albumTitle: 'Future Drift',
    artworkUrl:
        'https://images.unsplash.com/photo-1518709268805-4e9042af9f23?w=500&q=80',
    audioUrl: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-2.mp3',
    durationSeconds: 423,
  ),
  const Track(
    id: 't3',
    title: 'Starlight Odyssey',
    artistName: 'Solaris',
    albumTitle: 'Cosmos',
    artworkUrl:
        'https://images.unsplash.com/photo-1508700115892-45ecd05ae2ad?w=500&q=80',
    audioUrl: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-3.mp3',
    durationSeconds: 344,
  ),
];

// -----------------------------------------------------------------------------
// 3. STATE MANAGERS & PROVIDERS
// -----------------------------------------------------------------------------

class AudioPlayerState {
  final Track? currentTrack;
  final bool isPlaying;
  final Duration position;
  final Duration duration;
  final bool isShuffle;
  final bool isRepeat;

  const AudioPlayerState({
    this.currentTrack,
    this.isPlaying = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.isShuffle = false,
    this.isRepeat = false,
  });

  AudioPlayerState copyWith({
    Track? currentTrack,
    bool? isPlaying,
    Duration? position,
    Duration? duration,
    bool? isShuffle,
    bool? isRepeat,
  }) {
    return AudioPlayerState(
      currentTrack: currentTrack ?? this.currentTrack,
      isPlaying: isPlaying ?? this.isPlaying,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      isShuffle: isShuffle ?? this.isShuffle,
      isRepeat: isRepeat ?? this.isRepeat,
    );
  }
}

class AudioPlayerNotifier extends StateNotifier<AudioPlayerState> {
  Timer? _ticker;

  AudioPlayerNotifier() : super(const AudioPlayerState());

  void playTrack(Track track) {
    _ticker?.cancel();
    state = state.copyWith(
      currentTrack: track,
      isPlaying: true,
      position: Duration.zero,
      duration: Duration(seconds: track.durationSeconds),
    );

    _ticker = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (state.position.inSeconds >= state.duration.inSeconds) {
        if (state.isRepeat) {
          state = state.copyWith(position: Duration.zero);
        } else {
          pause();
        }
      } else {
        state = state.copyWith(
            position: state.position + const Duration(seconds: 1));
      }
    });
  }

  void togglePlayPause() {
    if (state.currentTrack == null) return;
    if (state.isPlaying) {
      pause();
    } else {
      state = state.copyWith(isPlaying: true);
      _ticker = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (state.position.inSeconds >= state.duration.inSeconds) {
          pause();
        } else {
          state = state.copyWith(
              position: state.position + const Duration(seconds: 1));
        }
      });
    }
  }

  void pause() {
    _ticker?.cancel();
    state = state.copyWith(isPlaying: false);
  }

  void seek(Duration pos) {
    state = state.copyWith(position: pos);
  }

  void toggleShuffle() => state = state.copyWith(isShuffle: !state.isShuffle);
  void toggleRepeat() => state = state.copyWith(isRepeat: !state.isRepeat);

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}

final playerProvider =
    StateNotifierProvider<AudioPlayerNotifier, AudioPlayerState>((ref) {
  return AudioPlayerNotifier();
});

class FavoritesNotifier extends StateNotifier<Set<String>> {
  FavoritesNotifier() : super({'t1'});

  void toggleFavorite(String trackId) {
    if (state.contains(trackId)) {
      state = {...state}..remove(trackId);
    } else {
      state = {...state, trackId};
    }
  }
}

final favoritesProvider =
    StateNotifierProvider<FavoritesNotifier, Set<String>>((ref) {
  return FavoritesNotifier();
});

class DownloadState {
  final Map<String, DownloadStatus> statuses;
  final Map<String, double> progress;

  const DownloadState({
    this.statuses = const {},
    this.progress = const {},
  });

  DownloadState copyWith({
    Map<String, DownloadStatus>? statuses,
    Map<String, double>? progress,
  }) {
    return DownloadState(
      statuses: statuses ?? this.statuses,
      progress: progress ?? this.progress,
    );
  }
}

class DownloadNotifier extends StateNotifier<DownloadState> {
  DownloadNotifier() : super(const DownloadState());

  Future<void> downloadTrack(Track track) async {
    final updatedStatuses = Map<String, DownloadStatus>.from(state.statuses);
    final updatedProgress = Map<String, double>.from(state.progress);

    updatedStatuses[track.id] = DownloadStatus.queued;
    state = state.copyWith(statuses: updatedStatuses);

    await Future.delayed(const Duration(milliseconds: 500));
    updatedStatuses[track.id] = DownloadStatus.downloading;
    state = state.copyWith(statuses: updatedStatuses);

    for (int i = 1; i <= 10; i++) {
      await Future.delayed(const Duration(milliseconds: 300));
      updatedProgress[track.id] = i / 10.0;
      state = state.copyWith(progress: Map.from(updatedProgress));
    }

    updatedStatuses[track.id] = DownloadStatus.completed;
    state = state.copyWith(statuses: updatedStatuses);
  }

  void deleteDownload(String trackId) {
    final updatedStatuses = Map<String, DownloadStatus>.from(state.statuses);
    final updatedProgress = Map<String, double>.from(state.progress);
    updatedStatuses.remove(trackId);
    updatedProgress.remove(trackId);
    state =
        state.copyWith(statuses: updatedStatuses, progress: updatedProgress);
  }
}

final downloadProvider =
    StateNotifierProvider<DownloadNotifier, DownloadState>((ref) {
  return DownloadNotifier();
});

// -----------------------------------------------------------------------------
// 4. MAIN ENTRY POINT & THEME CONFIGURATION
// -----------------------------------------------------------------------------

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: BellaMusicaApp()));
}

class BellaMusicaApp extends StatelessWidget {
  const BellaMusicaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bella Musica',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0F0F12),
        primaryColor: const Color(0xFF6C5CE7),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF6C5CE7),
          secondary: Color(0xFFA29BFE),
          surface: Color(0xFF18181E),
          error: Color(0xFFFF7675),
        ),
        cardColor: const Color(0xFF18181E),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0F0F12),
          elevation: 0,
        ),
      ),
      home: const NavigationShell(),
    );
  }
}

// -----------------------------------------------------------------------------
// 5. APPLICATION SHELL & NAVIGATION
// -----------------------------------------------------------------------------

class NavigationShell extends StatefulWidget {
  const NavigationShell({super.key});

  @override
  State<NavigationShell> createState() => _NavigationShellState();
}

class _NavigationShellState extends State<NavigationShell> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    HomeScreen(),
    SearchScreen(),
    LibraryScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          IndexedStack(
            index: _currentIndex,
            children: _screens,
          ),
          const Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: MiniPlayerOverlay(),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        backgroundColor: const Color(0xFF121216),
        selectedItemColor: const Color(0xFF6C5CE7),
        unselectedItemColor: Colors.white54,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_filled), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Search'),
          BottomNavigationBarItem(
              icon: Icon(Icons.library_music), label: 'Library'),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// 6. MINI PLAYER OVERLAY
// -----------------------------------------------------------------------------

class MiniPlayerOverlay extends ConsumerWidget {
  const MiniPlayerOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerState = ref.watch(playerProvider);
    final track = playerState.currentTrack;

    if (track == null) return const SizedBox.shrink();

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const FullScreenPlayer()),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF252530),
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [
            BoxShadow(
                color: Colors.black45, blurRadius: 8, offset: Offset(0, 4))
          ],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(track.artworkUrl,
                  width: 44, height: 44, fit: BoxFit.cover),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    track.title,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.white),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    track.artistName,
                    style: const TextStyle(fontSize: 12, color: Colors.white70),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            IconButton(
              icon:
                  Icon(playerState.isPlaying ? Icons.pause : Icons.play_arrow),
              onPressed: () =>
                  ref.read(playerProvider.notifier).togglePlayPause(),
            ),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// 7. HOME SCREEN
// -----------------------------------------------------------------------------

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_getGreeting(),
            style: const TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(icon: const Icon(Icons.settings), onPressed: () {}),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Featured Tracks',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          SizedBox(
            height: 200,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: kSampleTracks.length,
              itemBuilder: (context, index) {
                final track = kSampleTracks[index];
                return GestureDetector(
                  onTap: () =>
                      ref.read(playerProvider.notifier).playTrack(track),
                  child: Container(
                    width: 140,
                    margin: const EdgeInsets.only(right: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(track.artworkUrl,
                              width: 140, height: 140, fit: BoxFit.cover),
                        ),
                        const SizedBox(height: 8),
                        Text(track.title,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis),
                        Text(track.artistName,
                            style: const TextStyle(
                                color: Colors.white54, fontSize: 12)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 24),
          const Text('Recently Played',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          ...kSampleTracks.map((track) => ListTile(
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.network(track.artworkUrl,
                      width: 48, height: 48, fit: BoxFit.cover),
                ),
                title: Text(track.title,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(track.artistName),
                trailing: IconButton(
                  icon: const Icon(Icons.more_vert),
                  onPressed: () {},
                ),
                onTap: () => ref.read(playerProvider.notifier).playTrack(track),
              )),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// 8. SEARCH SCREEN
// -----------------------------------------------------------------------------

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final filteredTracks = kSampleTracks.where((t) {
      final q = _query.toLowerCase();
      return t.title.toLowerCase().contains(q) ||
          t.artistName.toLowerCase().contains(q);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          decoration: const InputDecoration(
            hintText: 'Search songs, artists, albums...',
            border: InputBorder.none,
            hintStyle: TextStyle(color: Colors.white54),
          ),
          style: const TextStyle(color: Colors.white),
          onChanged: (val) => setState(() => _query = val),
        ),
      ),
      body: ListView.builder(
        itemCount: filteredTracks.length,
        itemBuilder: (context, index) {
          final track = filteredTracks[index];
          return ListTile(
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.network(track.artworkUrl,
                  width: 48, height: 48, fit: BoxFit.cover),
            ),
            title: Text(track.title),
            subtitle: Text(track.artistName),
            onTap: () => ref.read(playerProvider.notifier).playTrack(track),
          );
        },
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// 9. LIBRARY & DOWNLOADS SCREEN
// -----------------------------------------------------------------------------

class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favorites = ref.watch(favoritesProvider);
    final downloadState = ref.watch(downloadProvider);

    final favoriteTracks =
        kSampleTracks.where((t) => favorites.contains(t.id)).toList();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Your Library'),
          bottom: const TabBar(
            indicatorColor: Color(0xFF6C5CE7),
            tabs: [
              Tab(text: 'Favorites'),
              Tab(text: 'Downloaded'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            ListView.builder(
              itemCount: favoriteTracks.length,
              itemBuilder: (context, index) {
                final track = favoriteTracks[index];
                return ListTile(
                  leading: Image.network(track.artworkUrl,
                      width: 48, height: 48, fit: BoxFit.cover),
                  title: Text(track.title),
                  subtitle: Text(track.artistName),
                  trailing: IconButton(
                    icon: const Icon(Icons.favorite, color: Color(0xFF6C5CE7)),
                    onPressed: () => ref
                        .read(favoritesProvider.notifier)
                        .toggleFavorite(track.id),
                  ),
                  onTap: () =>
                      ref.read(playerProvider.notifier).playTrack(track),
                );
              },
            ),
            ListView.builder(
              itemCount: kSampleTracks.length,
              itemBuilder: (context, index) {
                final track = kSampleTracks[index];
                final status = downloadState.statuses[track.id] ??
                    DownloadStatus.notDownloaded;
                final progress = downloadState.progress[track.id] ?? 0.0;

                return ListTile(
                  leading: Image.network(track.artworkUrl,
                      width: 48, height: 48, fit: BoxFit.cover),
                  title: Text(track.title),
                  subtitle: Text(status == DownloadStatus.downloading
                      ? 'Downloading ${(progress * 100).toInt()}%'
                      : track.artistName),
                  trailing: _buildDownloadButton(context, ref, track, status),
                  onTap: () =>
                      ref.read(playerProvider.notifier).playTrack(track),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDownloadButton(
      BuildContext context, WidgetRef ref, Track track, DownloadStatus status) {
    switch (status) {
      case DownloadStatus.notDownloaded:
        return IconButton(
          icon: const Icon(Icons.download),
          onPressed: () =>
              ref.read(downloadProvider.notifier).downloadTrack(track),
        );
      case DownloadStatus.queued:
      case DownloadStatus.downloading:
        return const SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2.5),
        );
      case DownloadStatus.completed:
        return IconButton(
          icon: const Icon(Icons.check_circle, color: Colors.green),
          onPressed: () =>
              ref.read(downloadProvider.notifier).deleteDownload(track.id),
        );
      case DownloadStatus.failed:
        return IconButton(
          icon: const Icon(Icons.error, color: Colors.red),
          onPressed: () =>
              ref.read(downloadProvider.notifier).downloadTrack(track),
        );
    }
  }
}

// -----------------------------------------------------------------------------
// 10. FULL SCREEN AUDIO PLAYER
// -----------------------------------------------------------------------------

class FullScreenPlayer extends ConsumerWidget {
  const FullScreenPlayer({super.key});

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerState = ref.watch(playerProvider);
    final favorites = ref.watch(favoritesProvider);
    final track = playerState.currentTrack;

    if (track == null) return const Scaffold();

    final isFav = favorites.contains(track.id);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.keyboard_arrow_down),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title:
            const Text('Playing from Library', style: TextStyle(fontSize: 14)),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          children: [
            const Spacer(),
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(track.artworkUrl,
                  width: 300, height: 300, fit: BoxFit.cover),
            ),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(track.title,
                        style: const TextStyle(
                            fontSize: 22, fontWeight: FontWeight.bold)),
                    Text(track.artistName,
                        style: const TextStyle(
                            fontSize: 16, color: Colors.white70)),
                  ],
                ),
                IconButton(
                  icon: Icon(isFav ? Icons.favorite : Icons.favorite_border,
                      color: isFav ? const Color(0xFF6C5CE7) : Colors.white),
                  onPressed: () => ref
                      .read(favoritesProvider.notifier)
                      .toggleFavorite(track.id),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Slider(
              value: playerState.position.inSeconds
                  .toDouble()
                  .clamp(0.0, playerState.duration.inSeconds.toDouble()),
              max: playerState.duration.inSeconds.toDouble() > 0
                  ? playerState.duration.inSeconds.toDouble()
                  : 1.0,
              activeColor: const Color(0xFF6C5CE7),
              onChanged: (val) {
                ref
                    .read(playerProvider.notifier)
                    .seek(Duration(seconds: val.toInt()));
              },
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(_formatDuration(playerState.position),
                    style: const TextStyle(color: Colors.white54)),
                Text(_formatDuration(playerState.duration),
                    style: const TextStyle(color: Colors.white54)),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  icon: Icon(Icons.shuffle,
                      color: playerState.isShuffle
                          ? const Color(0xFF6C5CE7)
                          : Colors.white54),
                  onPressed: () =>
                      ref.read(playerProvider.notifier).toggleShuffle(),
                ),
                IconButton(
                  icon: const Icon(Icons.skip_previous, size: 36),
                  onPressed: () {},
                ),
                IconButton(
                  iconSize: 64,
                  icon: Icon(
                      playerState.isPlaying
                          ? Icons.pause_circle_filled
                          : Icons.play_circle_filled,
                      color: const Color(0xFF6C5CE7)),
                  onPressed: () =>
                      ref.read(playerProvider.notifier).togglePlayPause(),
                ),
                IconButton(
                  icon: const Icon(Icons.skip_next, size: 36),
                  onPressed: () {},
                ),
                IconButton(
                  icon: Icon(Icons.repeat,
                      color: playerState.isRepeat
                          ? const Color(0xFF6C5CE7)
                          : Colors.white54),
                  onPressed: () =>
                      ref.read(playerProvider.notifier).toggleRepeat(),
                ),
              ],
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }
}
