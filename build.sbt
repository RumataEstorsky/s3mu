lazy val root = project
  .in(file("."))
  .settings(
    name                                   := "s3mu",
    version                                := "0.1.0-SNAPSHOT",
    scalaVersion                           := "2.13.18", // "3.7.4"
    libraryDependencies ++= Seq(
      "com.github.pureconfig" %% "pureconfig" % "0.17.9",
      "org.scalameta" %% "munit" % "1.2.1" % Test
    )
  )
