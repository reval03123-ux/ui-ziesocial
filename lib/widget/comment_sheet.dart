import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';
import 'package:provider/provider.dart';
import 'package:ziesocial/model/post_model.dart';
import 'package:ziesocial/view/login_view.dart';
import 'package:ziesocial/viewmodel/login_viewmodel.dart';
import 'package:ziesocial/viewmodel/post_viewmodel.dart';

class CommentSheet extends StatefulWidget {
  final PostModel post;

  const CommentSheet({super.key, required this.post});

  /// Menampilkan modal komentar setengah layar khas Instagram
  static void show(BuildContext context, PostModel post) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      enableDrag: true,
      useSafeArea: true,
      builder: (context) => CommentSheet(post: post),
    );
  }

  @override
  State<CommentSheet> createState() => _CommentSheetState();
}

class _CommentSheetState extends State<CommentSheet> {
  final _commentController = TextEditingController();
  final _focusNode = FocusNode();
  final _scrollController = ScrollController();

  List<CommentModel> _comments = [];
  bool _isLoading = true;
  bool _isSubmitting = false;

  // Untuk fitur reply dan edit
  CommentModel? _replyingTo;
  CommentModel? _editingComment;

  // Daftar quick emoji reaksi ala Instagram
  static const List<String> _quickEmojis = [
    '❤️',
    '🙌',
    '🔥',
    '👏',
    '😢',
    '😍',
    '😮',
    '😂',
  ];

  @override
  void initState() {
    super.initState();
    _commentController.addListener(_onTextChanged);
    _loadComments();
  }

  void _onTextChanged() {
    setState(() {});
  }

  @override
  void dispose() {
    _commentController.removeListener(_onTextChanged);
    _commentController.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadComments() async {
    setState(() => _isLoading = true);
    final postVm = context.read<PostViewModel>();
    final comments = await postVm.getComments(widget.post.id);
    if (!mounted) return;
    setState(() {
      _comments = comments;
      _isLoading = false;
    });
  }

  void _onEmojiTap(String emoji) {
    HapticFeedback.lightImpact();
    final user = context.read<LoginViewModel>().user;
    if (user == null) {
      _showSnackBar('Silakan login untuk berkomentar.');
      return;
    }

    final currentText = _commentController.text;
    final selection = _commentController.selection;

    if (selection.isValid && selection.start >= 0) {
      final newText = currentText.replaceRange(
        selection.start,
        selection.end,
        emoji,
      );
      _commentController.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(
          offset: selection.start + emoji.length,
        ),
      );
    } else {
      _commentController.text = currentText + emoji;
      _commentController.selection = TextSelection.collapsed(
        offset: _commentController.text.length,
      );
    }

    _focusNode.requestFocus();
    setState(() {});
  }

  void _startReply(CommentModel comment) {
    setState(() {
      _replyingTo = comment;
      _editingComment = null;
      _commentController.text = '@${comment.author.username} ';
    });
    _focusNode.requestFocus();
    _commentController.selection = TextSelection.fromPosition(
      TextPosition(offset: _commentController.text.length),
    );
    HapticFeedback.selectionClick();
  }

  void _startEdit(CommentModel comment) {
    setState(() {
      _editingComment = comment;
      _replyingTo = null;
      _commentController.text = comment.text;
    });
    _focusNode.requestFocus();
    _commentController.selection = TextSelection.fromPosition(
      TextPosition(offset: _commentController.text.length),
    );
    HapticFeedback.selectionClick();
  }

  void _cancelAction() {
    setState(() {
      _replyingTo = null;
      _editingComment = null;
      _commentController.clear();
    });
    _focusNode.unfocus();
  }

  Future<void> _submitComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    final user = context.read<LoginViewModel>().user;
    if (user == null) {
      _showSnackBar('Silakan login untuk berkomentar.');
      return;
    }

    final userId = int.tryParse(user.id) ?? 0;
    if (userId == 0) return;

    setState(() => _isSubmitting = true);
    _focusNode.unfocus();

    final postVm = context.read<PostViewModel>();
    bool success = false;

    if (_editingComment != null) {
      // Edit komentar
      success = await postVm.editComment(
        commentId: _editingComment!.id,
        userId: userId,
        text: text,
      );
      if (success && mounted) {
        setState(() {
          final idx = _comments.indexWhere((c) => c.id == _editingComment!.id);
          if (idx != -1) {
            _comments[idx] = CommentModel(
              id: _editingComment!.id,
              userId: _editingComment!.userId,
              postId: _editingComment!.postId,
              text: text,
              createDate: _editingComment!.createDate,
              author: _editingComment!.author,
            );
          }
        });
        _showSnackBar('Komentar berhasil diperbarui.');
      }
    } else {
      // Tambah komentar baru
      success = await postVm.addComment(
        postId: widget.post.id,
        userId: userId,
        text: text,
      );
      if (success) {
        await _loadComments();
        // Scroll ke komentar terbaru di bagian bawah
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      }
    }

    final wasEditing = _editingComment != null;

    if (!mounted) return;
    setState(() {
      _isSubmitting = false;
      _replyingTo = null;
      _editingComment = null;
    });
    _commentController.clear();

    if (!success) {
      _showSnackBar(wasEditing
          ? 'Gagal memperbarui komentar.'
          : 'Gagal menambahkan komentar.');
    }
  }

  Future<void> _deleteComment(CommentModel comment) async {
    final user = context.read<LoginViewModel>().user;
    if (user == null) return;
    final userId = int.tryParse(user.id) ?? 0;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Hapus Komentar?',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Komentar ini akan dihapus secara permanen.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Batal',
                style: TextStyle(color: Colors.grey.shade600)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    final postVm = context.read<PostViewModel>();
    final success = await postVm.deleteComment(
      commentId: comment.id,
      postId: widget.post.id,
      userId: userId,
    );

    if (!mounted) return;
    if (success) {
      setState(() => _comments.removeWhere((c) => c.id == comment.id));
      _showSnackBar('Komentar berhasil dihapus.');
    } else {
      _showSnackBar('Gagal menghapus komentar.');
    }
  }

  void _showCommentOptions(CommentModel comment, bool isMyComment) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.reply_rounded, color: Color(0xFF3366A0)),
              title: const Text('Balas',
                  style: TextStyle(fontWeight: FontWeight.w500)),
              onTap: () {
                Navigator.pop(context);
                _startReply(comment);
              },
            ),
            if (isMyComment) ...[
              ListTile(
                leading: const Icon(Icons.edit_outlined, color: Color(0xFF3366A0)),
                title: const Text('Edit Komentar',
                    style: TextStyle(fontWeight: FontWeight.w500)),
                onTap: () {
                  Navigator.pop(context);
                  _startEdit(comment);
                },
              ),
              ListTile(
                leading: Icon(Icons.delete_outline, color: Colors.red.shade400),
                title: Text('Hapus',
                    style: TextStyle(
                        color: Colors.red.shade400,
                        fontWeight: FontWeight.w500)),
                onTap: () {
                  Navigator.pop(context);
                  _deleteComment(comment);
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.grey.shade900,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<LoginViewModel>().user;
    final currentUserId = user != null ? int.tryParse(user.id) ?? 0 : 0;

    final mediaQuery = MediaQuery.of(context);
    final keyboardPadding = mediaQuery.viewInsets.bottom;
    final screenHeight = mediaQuery.size.height;
    final topSafeArea = mediaQuery.padding.top;

    // Batas tinggi aman maksimal agar modal tidak pernah menembus layar atau overflow
    final double maxAvailableHeight = screenHeight - topSafeArea - 24;

    // Saat keyboard muncul: kurangi keyboardPadding dari batas tinggi agar tidak overflow
    // Saat keyboard tertutup: gunakan proporsi ~65% tinggi layar khas Instagram
    final double currentMaxHeight = keyboardPadding > 0
        ? (maxAvailableHeight - keyboardPadding).clamp(180.0, maxAvailableHeight)
        : (screenHeight * 0.65).clamp(260.0, maxAvailableHeight);

    final hasCaption = widget.post.caption.trim().isNotEmpty;
    final totalListCount = (hasCaption ? 1 : 0) + _comments.length;

    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600),
        child: AnimatedPadding(
          padding: EdgeInsets.only(bottom: keyboardPadding),
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          child: Container(
            constraints: BoxConstraints(maxHeight: currentMaxHeight),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 16,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              bottom: keyboardPadding == 0,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── Header (Drag Handle & Judul) ──
                  _buildHeader(),

                  // ── Daftar Komentar (Scrollable) ──
                  Flexible(
                    child: _isLoading
                        ? const Center(
                            child: CircularProgressIndicator(
                              color: Color(0xFF3366A0),
                              strokeWidth: 2,
                            ),
                          )
                        : _comments.isEmpty && !hasCaption
                            ? _buildEmptyState()
                            : ListView.builder(
                                controller: _scrollController,
                                physics: const AlwaysScrollableScrollPhysics(
                                  parent: BouncingScrollPhysics(),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                itemCount: totalListCount + (_comments.isEmpty && hasCaption ? 1 : 0),
                                itemBuilder: (context, index) {
                                  // Tampilkan caption pembuat postingan di paling atas (seperti IG)
                                  if (hasCaption && index == 0) {
                                    return _buildPostCaptionTile();
                                  }

                                  // Jika caption ada tapi komentar masih kosong
                                  if (hasCaption && _comments.isEmpty && index == 1) {
                                    return _buildEmptyState();
                                  }

                                  final commentIndex = hasCaption ? index - 1 : index;
                                  final comment = _comments[commentIndex];
                                  final isMyComment = currentUserId > 0 &&
                                      comment.userId == currentUserId;

                                  return _buildCommentTile(
                                    comment,
                                    isMyComment,
                                    currentUserId,
                                  );
                                },
                              ),
                  ),

                  // ── Indikator Balas / Edit ──
                  if (_replyingTo != null || _editingComment != null)
                    _buildActionIndicator(),

                  // ── Quick Emojis Bar (Khas Instagram) ──
                  _buildQuickEmojisBar(),

                  // ── Input Bar ──
                  if (user != null)
                    _buildInputBar(user.avatarUrl)
                  else
                    _buildLoginPrompt(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Header modal dengan handle drag & judul "Komentar"
  Widget _buildHeader() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Pill handle
        Container(
          margin: const EdgeInsets.only(top: 10, bottom: 6),
          width: 38,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.grey.shade300,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        // Title row
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
          child: Row(
            children: [
              const SizedBox(width: 24),
              const Expanded(
                child: Text(
                  'Komentar',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: const Icon(Icons.close, size: 20, color: Colors.black54),
              ),
            ],
          ),
        ),
        const Divider(height: 1, thickness: 0.5, color: Color(0xFFEEEEEE)),
      ],
    );
  }

  /// Caption pembuat postingan ditampilkan sebagai komentar utama paling atas (seperti IG)
  Widget _buildPostCaptionTile() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade100, width: 0.8),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAvatar(widget.post.author, hasStoryRing: true),
          const Gap(12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        widget.post.author.username.isNotEmpty
                            ? widget.post.author.username
                            : widget.post.author.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: Colors.black87,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const Gap(6),
                    Text(
                      _formatDate(widget.post.createDate),
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade400,
                      ),
                    ),
                  ],
                ),
                const Gap(4),
                Text(
                  widget.post.caption,
                  style: const TextStyle(
                    fontSize: 13.5,
                    color: Colors.black87,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Tampilan kosong jika belum ada yang berkomentar
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.chat_bubble_outline_rounded,
              size: 44,
              color: Colors.grey.shade300,
            ),
            const Gap(10),
            const Text(
              'Belum ada komentar',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const Gap(4),
            Text(
              'Mulai percakapan dengan menambahkan komentar.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: 12.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Item satu baris komentar
  Widget _buildCommentTile(
    CommentModel comment,
    bool isMyComment,
    int currentUserId,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar
          _buildAvatar(comment.author),
          const Gap(12),

          // Konten Komentar
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header (Nama & Waktu)
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        comment.author.username.isNotEmpty
                            ? comment.author.username
                            : comment.author.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: Colors.black87,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const Gap(6),
                    Text(
                      _formatDate(comment.createDate),
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade400,
                      ),
                    ),
                    if (_editingComment?.id == comment.id) ...[
                      const Gap(6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8EFF8),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'Sedang diedit',
                          style: TextStyle(
                            fontSize: 10,
                            color: Color(0xFF3366A0),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const Gap(3),

                // Teks Komentar
                Text(
                  comment.text,
                  style: const TextStyle(
                    fontSize: 13.5,
                    color: Colors.black87,
                    height: 1.35,
                  ),
                ),
                const Gap(6),

                // Aksi Balas
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => _startReply(comment),
                      child: Text(
                        'Balas',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Menu Opsi (Titik Tiga)
          GestureDetector(
            onTap: () => _showCommentOptions(comment, isMyComment),
            child: Padding(
              padding: const EdgeInsets.only(left: 6, top: 2),
              child: Icon(
                Icons.more_horiz,
                size: 18,
                color: Colors.grey.shade400,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Avatar pembuat komentar
  Widget _buildAvatar(AuthorModel author, {bool hasStoryRing = false}) {
    final avatarWidget = CircleAvatar(
      radius: 16,
      backgroundColor: const Color(0xFFE8EFF8),
      child: author.avatar.isNotEmpty
          ? ClipOval(
              child: Image.network(
                author.avatarUrl,
                width: 32,
                height: 32,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    _initial(author.name),
              ),
            )
          : _initial(author.name),
    );

    if (hasStoryRing) {
      return Container(
        width: 38,
        height: 38,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [Color(0xFF833AB4), Color(0xFFFD1D1D), Color(0xFFFCB045)],
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
          ),
        ),
        padding: const EdgeInsets.all(1.5),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
          padding: const EdgeInsets.all(1),
          child: avatarWidget,
        ),
      );
    }

    return avatarWidget;
  }

  Widget _initial(String name) {
    return Text(
      name.isNotEmpty ? name[0].toUpperCase() : '?',
      style: const TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: 12,
        color: Color(0xFF3366A0),
      ),
    );
  }

  /// Baris Quick Emoji Reaksi Khas Instagram
  Widget _buildQuickEmojisBar() {
    return Container(
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Colors.grey.shade200, width: 0.6),
        ),
      ),
      child: Center(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: _quickEmojis.map((emoji) {
              return Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _onEmojiTap(emoji),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    child: Text(
                      emoji,
                      style: const TextStyle(fontSize: 22),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  /// Indikator ketika sedang membalas atau mengedit komentar
  Widget _buildActionIndicator() {
    final isReply = _replyingTo != null;
    final name = isReply
        ? (_replyingTo!.author.name.isNotEmpty
            ? _replyingTo!.author.name
            : _replyingTo!.author.username)
        : null;

    return Container(
      color: const Color(0xFFF5F7FA),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(
            isReply ? Icons.reply_rounded : Icons.edit_outlined,
            size: 16,
            color: const Color(0xFF3366A0),
          ),
          const Gap(8),
          Expanded(
            child: Text(
              isReply ? 'Membalas @$name' : 'Mengedit komentar',
              style: const TextStyle(
                fontSize: 12.5,
                color: Color(0xFF3366A0),
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          GestureDetector(
            onTap: _cancelAction,
            child: Icon(Icons.close, size: 16, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  /// Kolom input komentar dengan avatar user di sebelah kiri
  Widget _buildInputBar(String currentUserAvatarUrl) {
    final hasText = _commentController.text.trim().isNotEmpty;
    final hint = _editingComment != null
        ? 'Edit komentar...'
        : _replyingTo != null
            ? 'Tulis balasan...'
            : 'Tambahkan komentar untuk @${widget.post.author.username}...';

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Avatar user yang sedang login
          CircleAvatar(
            radius: 17,
            backgroundColor: const Color(0xFFE8EFF8),
            child: currentUserAvatarUrl.isNotEmpty
                ? ClipOval(
                    child: Image.network(
                      currentUserAvatarUrl,
                      width: 34,
                      height: 34,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          const Icon(Icons.person, size: 18, color: Color(0xFF3366A0)),
                    ),
                  )
                : const Icon(Icons.person, size: 18, color: Color(0xFF3366A0)),
          ),
          const Gap(10),

          // Field Teks Komentar
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _commentController,
                      focusNode: _focusNode,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _submitComment(),
                      minLines: 1,
                      maxLines: 4,
                      style: const TextStyle(fontSize: 13.5, color: Colors.black87),
                      decoration: InputDecoration(
                        hintText: hint,
                        hintStyle: TextStyle(
                          color: Colors.grey.shade400,
                          fontSize: 13,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        border: InputBorder.none,
                        isDense: true,
                      ),
                    ),
                  ),

                  // Tombol Kirim / Posting
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: Padding(
                              padding: EdgeInsets.all(4),
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFF3366A0),
                              ),
                            ),
                          )
                        : GestureDetector(
                            onTap: hasText ? _submitComment : null,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              child: Text(
                                _editingComment != null ? 'Simpan' : 'Kirim',
                                style: TextStyle(
                                  color: hasText
                                      ? const Color(0xFF3366A0)
                                      : Colors.grey.shade400,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13.5,
                                ),
                              ),
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Ajakan login jika pengunjung belum login
  Widget _buildLoginPrompt() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Ingin berkomentar? ',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
          ),
          GestureDetector(
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LoginView()),
              );
            },
            child: const Text(
              'Masuk di sini',
              style: TextStyle(
                color: Color(0xFF3366A0),
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr.replaceAll(' ', 'T'));
      final now = DateTime.now();
      final diff = now.difference(date);
      if (diff.inMinutes < 1) return 'baru saja';
      if (diff.inHours < 1) return '${diff.inMinutes}m';
      if (diff.inDays < 1) return '${diff.inHours}j';
      if (diff.inDays < 7) return '${diff.inDays}h';
      return dateStr.split(' ').first;
    } catch (_) {
      return dateStr;
    }
  }
}
