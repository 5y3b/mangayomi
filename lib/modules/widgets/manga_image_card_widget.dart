import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:isar_community/isar.dart';
import 'package:mangayomi/eval/model/m_manga.dart';
import 'package:mangayomi/main.dart';
import 'package:mangayomi/models/manga.dart';
import 'package:mangayomi/models/settings.dart';
import 'package:mangayomi/models/source.dart';
import 'package:mangayomi/modules/manga/detail/manga_detail_main.dart';
import 'package:mangayomi/modules/widgets/custom_extended_image_provider.dart';
import 'package:mangayomi/router/router.dart';
import 'package:mangayomi/utils/extensions/build_context_extensions.dart';
import 'package:mangayomi/utils/constant.dart';
import 'package:mangayomi/utils/headers.dart';
import 'package:mangayomi/modules/widgets/bottom_text_widget.dart';
import 'package:mangayomi/modules/widgets/cover_view_widget.dart';

class MangaImageCardWidget extends ConsumerWidget {
  final Source source;
  final ItemType itemType;
  final bool isComfortableGrid;
  final MManga? getMangaDetail;

  const MangaImageCardWidget({
    required this.source,
    super.key,
    required this.getMangaDetail,
    required this.isComfortableGrid,
    required this.itemType,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return StreamBuilder(
      stream: isar.mangas
          .filter()
          .langEqualTo(source.lang)
          .nameEqualTo(getMangaDetail!.name)
          .sourceEqualTo(source.name)
          .watch(fireImmediately: true),
      builder: (context, snapshot) {
        bool hasData = snapshot.hasData;
        final mangaList = hasData
            ? snapshot.data!
                  .where(
                    (element) => element.sourceId == null
                        ? true
                        : element.sourceId == source.id,
                  )
                  .toList()
            : [];
        hasData = hasData && mangaList.isNotEmpty;
        return CoverViewWidget(
          bottomTextWidget: BottomTextWidget(
            maxLines: 1,
            text: getMangaDetail!.name!,
            isComfortableGrid: isComfortableGrid,
          ),
          isComfortableGrid: isComfortableGrid,
          image: hasData && mangaList.first.customCoverImage != null
              ? MemoryImage(mangaList.first.customCoverImage as Uint8List)
                    as ImageProvider
              : CustomExtendedNetworkImageProvider(
                  toImgUrl(
                    hasData
                        ? mangaList.first.customCoverFromTracker ??
                              mangaList.first.imageUrl ??
                              ""
                        : getMangaDetail!.imageUrl ?? "",
                  ),
                  headers: ref.watch(
                    headersProvider(
                      source: source.name!,
                      lang: source.lang!,
                      sourceId: source.id,
                    ),
                  ),
                  cache: true,
                  cacheMaxAge: const Duration(days: 7),
                ),
          onTap: () {
            pushToMangaReaderDetail(
              ref: ref,
              context: context,
              getManga: getMangaDetail!,
              lang: source.lang!,
              source: source.name!,
              itemType: itemType,
              sourceId: source.id,
            );
          },
          onLongPress: () {
            pushToMangaReaderDetail(
              ref: ref,
              context: context,
              getManga: getMangaDetail!,
              lang: source.lang!,
              source: source.name!,
              itemType: itemType,
              addToFavourite: true,
              sourceId: source.id,
            );
          },
          onSecondaryTap: () {
            pushToMangaReaderDetail(
              ref: ref,
              context: context,
              getManga: getMangaDetail!,
              lang: source.lang!,
              source: source.name!,
              itemType: itemType,
              addToFavourite: true,
              sourceId: source.id,
            );
          },
          children: [
            Container(
              color: hasData && mangaList.first.favorite!
                  ? Colors.black.withValues(alpha: 0.5)
                  : null,
            ),
            if (hasData && mangaList.first.favorite!)
              Positioned(
                top: 0,
                left: 0,
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Container(
                    decoration: BoxDecoration(
                      color: context.primaryColor,
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        Icons.collections_bookmark_outlined,
                        size: 16,
                        color: context.dynamicWhiteBlackColor,
                      ),
                    ),
                  ),
                ),
              ),
            if (!isComfortableGrid)
              BottomTextWidget(
                isTorrent: source.isTorrent,
                text: getMangaDetail!.name!,
              ),
          ],
        );
      },
    );
  }
}

class MangaImageCardListTileWidget extends ConsumerWidget {
  final Source source;
  final ItemType itemType;
  final MManga? getMangaDetail;

  const MangaImageCardListTileWidget({
    required this.source,
    super.key,
    required this.itemType,
    required this.getMangaDetail,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return StreamBuilder(
      stream: isar.mangas
          .filter()
          .langEqualTo(source.lang)
          .nameEqualTo(getMangaDetail!.name)
          .sourceEqualTo(source.name)
          .watch(fireImmediately: true),
      builder: (context, snapshot) {
        bool hasData = snapshot.hasData;
        final mangaList = hasData
            ? snapshot.data!
                  .where(
                    (element) => element.sourceId == null
                        ? true
                        : element.sourceId == source.id,
                  )
                  .toList()
            : [];
        hasData = hasData && mangaList.isNotEmpty;
        final image = hasData && mangaList.first.customCoverImage != null
            ? MemoryImage(mangaList.first.customCoverImage as Uint8List)
                  as ImageProvider
            : CustomExtendedNetworkImageProvider(
                toImgUrl(
                  hasData
                      ? mangaList.first.customCoverFromTracker ??
                            mangaList.first.imageUrl ??
                            ""
                      : getMangaDetail!.imageUrl ?? "",
                ),
                headers: ref.watch(
                  headersProvider(
                    source: source.name!,
                    lang: source.lang!,
                    sourceId: source.id,
                  ),
                ),
              );
        return Padding(
          padding: const EdgeInsets.all(8.0),
          child: Material(
            borderRadius: BorderRadius.circular(5),
            color: Colors.transparent,
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () {
                pushToMangaReaderDetail(
                  ref: ref,
                  context: context,
                  getManga: getMangaDetail!,
                  lang: source.lang!,
                  source: source.name!,
                  itemType: itemType,
                  sourceId: source.id,
                );
              },
              onLongPress: () {
                pushToMangaReaderDetail(
                  ref: ref,
                  context: context,
                  getManga: getMangaDetail!,
                  lang: source.lang!,
                  source: source.name!,
                  itemType: itemType,
                  addToFavourite: true,
                  sourceId: source.id,
                );
              },
              onSecondaryTap: () {
                pushToMangaReaderDetail(
                  ref: ref,
                  context: context,
                  getManga: getMangaDetail!,
                  lang: source.lang!,
                  source: source.name!,
                  itemType: itemType,
                  addToFavourite: true,
                  sourceId: source.id,
                );
              },
              child: Row(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Stack(
                      children: [
                        Material(
                          borderRadius: BorderRadius.circular(5),
                          color: Colors.transparent,
                          clipBehavior: Clip.antiAlias,
                          child: Image(
                            height: 55,
                            width: 40,
                            fit: BoxFit.cover,
                            image: image,
                          ),
                        ),
                        Container(
                          height: 55,
                          width: 40,
                          color: hasData && mangaList.first.favorite!
                              ? Colors.black.withValues(alpha: 0.5)
                              : null,
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Text(
                      getMangaDetail!.name!,
                      maxLines: 2,
                      style: TextStyle(
                        overflow: TextOverflow.ellipsis,
                        color: context.textColor,
                      ),
                    ),
                  ),
                  if (hasData && mangaList.first.favorite!)
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Container(
                        decoration: BoxDecoration(
                          color: context.primaryColor,
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Icon(
                            Icons.collections_bookmark_outlined,
                            size: 16,
                            color: context.dynamicWhiteBlackColor,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

Future<void> pushToMangaReaderDetail({
  MManga? getManga,
  required WidgetRef ref,
  required String lang,
  required BuildContext context,
  required String source,
  required int? sourceId,
  int? archiveId,
  Manga? mangaM,
  ItemType? itemType,
  bool useMaterialRoute = false,
  bool addToFavourite = false,
}) async {
  int? mangaId;
  mangaId = isar.mangas
      .filter()
      .isLocalArchiveEqualTo(true)
      .sourceEqualTo("local")
      .nameEqualTo(getManga?.name)
      .findFirstSync()
      ?.id;

  if (mangaId == null) {
    if (archiveId == null) {
      final manga =
          mangaM ??
          Manga(
            imageUrl: getManga!.imageUrl,
            name: getManga.name!.trim(),
            genre: getManga.genre?.map((e) => e.toString()).toList() ?? [],
            author: getManga.author ?? "",
            status: getManga.status ?? Status.unknown,
            description: getManga.description ?? "",
            link: getManga.link,
            source: source,
            lang: lang,
            lastUpdate: 0,
            itemType: itemType ?? ItemType.manga,
            artist: getManga.artist ?? '',
            sourceId: sourceId,
          );
      final empty = isar.mangas
          .filter()
          .langEqualTo(lang)
          .nameEqualTo(manga.name)
          .sourceEqualTo(manga.source)
          .isEmptySync();
      if (empty) {
        isar.writeTxnSync(() {
          isar.mangas.putSync(
            manga..updatedAt = DateTime.now().millisecondsSinceEpoch,
          );
        });
      } else {
        isar.writeTxnSync(() {
          isar.mangas.putSync(manga);
        });
      }

      final matchingEntries = isar.mangas
          .filter()
          .langEqualTo(lang)
          .nameEqualTo(manga.name)
          .sourceEqualTo(manga.source)
          .findAllSync();
      final matchedManga = matchingEntries.firstWhere(
        (element) => element.sourceId == sourceId,
        orElse: () => matchingEntries.first,
      );
      mangaId = matchedManga.id!;
    } else {
      mangaId = archiveId;
    }
  }

  final mang = isar.mangas.getSync(mangaId);
  if (mang != null &&
      !(mang.isLocalArchive ?? false) &&
      getManga != null &&
      archiveId == null) {
    isar.writeTxnSync(() {
      isar.mangas.putSync(
        mang
          ..sourceId = sourceId
          ..link = getManga.link?.trim().isNotEmpty == true
              ? getManga.link!.trim()
              : mang.link
          ..imageUrl = getManga.imageUrl?.trim().isNotEmpty == true
              ? getManga.imageUrl!.trim()
              : mang.imageUrl
          ..name = getManga.name?.trim().isNotEmpty == true
              ? getManga.name!.trim()
              : mang.name
          ..author = getManga.author?.trim().isNotEmpty == true
              ? getManga.author!.trim()
              : mang.author
          ..artist = getManga.artist?.trim().isNotEmpty == true
              ? getManga.artist!.trim()
              : mang.artist
          ..description = getManga.description?.trim().isNotEmpty == true
              ? getManga.description!.trim()
              : mang.description
          ..genre =
              getManga.genre?.isNotEmpty == true
              ? getManga.genre!.map((e) => e.toString()).toList()
              : mang.genre
          ..status = getManga.status ?? mang.status
          ..itemType = itemType ?? mang.itemType
          ..lang = lang
          ..source = source
          ..updatedAt = DateTime.now().millisecondsSinceEpoch,
      );
    });
  }
  final settings = isar.settings.getSync(227)!;
  final sortList = settings.sortChapterList ?? [];
  final checkIfExist = sortList
      .where((element) => element.mangaId == mangaId)
      .toList();
  if (checkIfExist.isEmpty) {
    isar.writeTxnSync(() {
      List<SortChapter>? sortChapterList = [];
      for (var sortChapter in settings.sortChapterList ?? []) {
        sortChapterList.add(sortChapter);
      }
      List<ChapterFilterBookmarked>? chapterFilterBookmarkedList = [];
      for (var sortChapter in settings.chapterFilterBookmarkedList ?? []) {
        chapterFilterBookmarkedList.add(sortChapter);
      }
      List<ChapterFilterDownloaded>? chapterFilterDownloadedList = [];
      for (var sortChapter in settings.chapterFilterDownloadedList ?? []) {
        chapterFilterDownloadedList.add(sortChapter);
      }
      List<ChapterFilterUnread>? chapterFilterUnreadList = [];
      for (var sortChapter in settings.chapterFilterUnreadList ?? []) {
        chapterFilterUnreadList.add(sortChapter);
      }
      sortChapterList.add(SortChapter()..mangaId = mangaId);
      chapterFilterBookmarkedList.add(
        ChapterFilterBookmarked()..mangaId = mangaId,
      );
      chapterFilterDownloadedList.add(
        ChapterFilterDownloaded()..mangaId = mangaId,
      );
      chapterFilterUnreadList.add(ChapterFilterUnread()..mangaId = mangaId);
      isar.settings.putSync(
        settings
          ..sortChapterList = sortChapterList
          ..chapterFilterBookmarkedList = chapterFilterBookmarkedList
          ..chapterFilterDownloadedList = chapterFilterDownloadedList
          ..chapterFilterUnreadList = chapterFilterUnreadList
          ..updatedAt = DateTime.now().millisecondsSinceEpoch,
      );
    });
  }
  if (!addToFavourite) {
    if (useMaterialRoute) {
      await Navigator.push(
        context,
        createRoute(page: MangaReaderDetail(mangaId: mangaId)),
      );
    } else {
      await context.push('/manga-reader/detail', extra: mangaId);
    }
  } else {
    final getManga = isar.mangas.filter().idEqualTo(mangaId).findFirstSync()!;
    isar.writeTxnSync(() {
      isar.mangas.putSync(
        getManga
          ..favorite = !getManga.favorite!
          ..updatedAt = DateTime.now().millisecondsSinceEpoch,
      );
    });
  }
}
