import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:stingray/component/comment_tile.dart';
import 'package:stingray/component/loading_stories.dart';
import 'package:stingray/model/item.dart';
import 'package:stingray/repo.dart';

final commentsProvider = FutureProvider.family((ref, int id) async {
  return await Repo.fetchItem(id);
});

class CommentList extends HookWidget {
  const CommentList({
    Key key,
    @required this.item,
  }) : super(key: key);

  final Item item;

  @override
  Widget build(BuildContext context) {
    useMemoized(() {
      Repo.prefetchComments(item: item);
    });

    final collapsed = useState(Set());
    final ids = useState([]);
    Stream<int> stream;
    useEffect(() {
      stream = Repo.lazyFetchComments(item: item);
      final sub = stream.listen((int comment) {
        ids.value = [...ids.value, comment];
      });
      return sub.cancel;
    }, [stream]);

    return SliverPadding(
      padding: const EdgeInsets.all(8.0),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            Widget _child = (ids.value.isEmpty || index > ids.value.length - 1)
                ? LoadingStories(count: 1)
                : Consumer(
                    (context, read) {
                      return read(commentsProvider(ids.value[index])).when(
                        loading: () => LoadingStories(count: 1),
                        error: (err, trace) => Text(err),
                        data: (comment) {
                          Set result = Set.from(collapsed.value);
                          return InkWell(
                            onTap: () {
                              if (comment.kids.isEmpty) return;

                              if (collapsed.value.contains(comment.id)) {
                                result.remove(comment.id);
                              } else {
                                result.add(comment.id);
                                result.addAll(comment.kids);
                              }
                              collapsed.value = result;
                            },
                            child: AnimatedSwitcher(
                              duration: Duration(milliseconds: 500),
                              switchInCurve: Curves.easeInOut,
                              switchOutCurve: Curves.easeInOut,
                              child: collapsed.value.contains(comment.parent)
                                  ? Container()
                                  : CommentTile(
                                      comment: comment,
                                      author: item.by,
                                      isCollapsed:
                                          collapsed.value.contains(comment.id),
                                    ),
                            ),
                          );
                        },
                      );
                    },
                  );

            return AnimatedSwitcher(
              switchInCurve: Curves.easeInOut,
              duration: Duration(seconds: 1),
              child: _child,
            );
          },
          childCount: item.descendants,
        ),
      ),
    );
  }
}
