lazy val root = project
  .in(file("."))
  .settings(
    name                                   := "s3mu",
    version                                := "0.1.0-SNAPSHOT",
    scalaVersion                           := "2.13.18", // "3.7.4"
    libraryDependencies += "org.scalameta" %% "munit" % "1.2.1" % Test,
  )
