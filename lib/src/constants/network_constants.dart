// ignore_for_file: constant_identifier_names, non_constant_identifier_names

/// Data container containing network constants.
class NetConsts {
  // [Dio] configuration.
  static const String APPLICATION_JSON = "application/json";
  static const String CONTENT_TYPE = "content-type";
  static const String AUTHORIZATION = "Authorization";
  static const String ACCEPT = "accept";
  static const int API_TIMEOUT = 20000;

  // Used for [VersionCheck].
  static const String URL_CHECK_VERSION =
      "https://raw.githubusercontent.com/Kdroidwin/VNSRB/refs/heads/master/VERSION.json";
  static const String URL_UPDATE_VERSION =
      "https://github.com/Kdroidwin/VNSRB/releases/latest";

  /// Hosts used by Dio-backed application APIs. Redirects are disabled so
  /// authenticated or user-specific requests cannot be forwarded elsewhere.
  static const Set<String> TRUSTED_HTTPS_HOSTS = {
    'api.vndb.org',
    'raw.githubusercontent.com',
  };
  static const Set<String> TRUSTED_IMAGE_HOSTS = {'t.vndb.org'};

  // API base url.
  static const String BASE_URL = "https://api.vndb.org";

  static const String P1_FIELDS =
      "title, titles.lang, titles.title, image.url, image.sexual, image.violence, image.thumbnail, length, rating, "
      "votecount, olang, released, description";

  static const String P2a_FIELDS =
      "aliases, length_minutes, devstatus, developers{id,name,original}, screenshots.id, "
      "screenshots.sexual, screenshots.violence, tags.id, tags.spoiler, tags.name, tags.rating, platforms, languages";

  static const String P2b_FIELDS = "minage, languages.mtl, languages.lang";

  static const String P3_FIELDS =
      "extlinks.url, relations.id, relations.title, relations.titles.lang, relations.titles.title, relations.relation, relations.relation_official, "
      "relations.image.url, relations.image.sexual, relations.image.violence, relations.image.thumbnail, "
      "relations.length, relations.votecount, relations.olang, relations.released, relations.rating, "
      "relations.description";

  static const String USER_VNS_FIELDS =
      "id, vote, vn.title, added, started, finished, labels.label, lastmod, notes";
}
