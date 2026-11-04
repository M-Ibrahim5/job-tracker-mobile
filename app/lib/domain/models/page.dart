/// One page of a paginated list response.
class Page<T> {
  /// Creates a page.
  const Page({
    required this.items,
    required this.page,
    required this.pageSize,
    required this.total,
  });

  /// Parses `{ items, page, pageSize, total }`.
  factory Page.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) itemFromJson,
  ) {
    return Page(
      items: (json['items'] as List)
          .map((e) => itemFromJson(e as Map<String, dynamic>))
          .toList(),
      page: json['page'] as int,
      pageSize: json['pageSize'] as int,
      total: json['total'] as int,
    );
  }

  final List<T> items;
  final int page;
  final int pageSize;
  final int total;

  /// Whether more pages follow this one.
  bool get hasMore => page * pageSize < total;
}
