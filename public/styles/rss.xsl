<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet
  version="1.0"
  exclude-result-prefixes="xhtml"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:xhtml="http://www.w3.org/1999/xhtml">

  <xsl:output
    method="html"
    doctype-system="http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd"
    doctype-public="-//W3C//DTD XHTML 1.0 Transitional//EN"/>

  <xsl:variable name="channelTitle" select="/rss/channel/title"/>

  <xsl:template match="/">
    <xsl:element name="html">
      <head>
        <title><xsl:value-of select="$channelTitle"/></title>
      </head>
      <xsl:apply-templates select="rss/channel"/>
    </xsl:element>
  </xsl:template>

  <xsl:template match="channel">
    <body>

      <div id="header">
        <xsl:apply-templates select="image"/>
        <h1>
          <xsl:choose>
            <xsl:when test="link">
              <a title="channel link" href="{link}">
                <xsl:value-of select="$channelTitle"/>
              </a>
            </xsl:when>
            <xsl:otherwise>
              <xsl:value-of select="$channelTitle"/>
            </xsl:otherwise>
          </xsl:choose>
        </h1>
        <p style="clear:both"/>
      </div>

      <div id="items">
        <xsl:apply-templates select="item"/>
      </div>

      <div id="footer">
      </div>
    </body>
  </xsl:template>

  <xsl:template match="image">
    <a href="{link}" title="Link to original website"><img src="{url}" id="feedimage" alt="{title}"/></a>
    <xsl:text/>
  </xsl:template>

  <xsl:template match="item" xmlns:dc="http://purl.org/dc/elements/1.1/">
    <xsl:if test="position() = 1">
      <h3 id="currentFeedContent">Items</h3>
    </xsl:if>
    <ul>
      <li class="regularitem">
        <h4>
          <xsl:choose>
            <xsl:when test="link">
              <a href="{link}"><xsl:value-of select="title"/></a>
            </xsl:when>
            <xsl:when test="guid[@isPermaLink='true' or not(@isPermaLink)]">
              <a href="{guid}"><xsl:value-of select="title"/></a>
            </xsl:when>
            <xsl:otherwise><xsl:value-of select="title"/></xsl:otherwise>
          </xsl:choose>
        </h4>
        <h5>
          <xsl:if test="count(child::pubDate)=1">
            <span>Posted:</span><xsl:text> </xsl:text><xsl:value-of select="pubDate"/>
          </xsl:if>
          <xsl:if test="count(child::dc:date)=1">
            <span>Posted:</span><xsl:text> </xsl:text><xsl:value-of select="dc:date"/>
          </xsl:if>
        </h5>
        <xsl:if test="count(child::enclosure)=1">
          <audio src="{enclosure/@url}" controls="controls" preload="metadata"></audio>
        </xsl:if>
        <div>
          <xsl:choose>
            <xsl:when xmlns:content="http://purl.org/rss/1.0/modules/content/" test="content:encoded">
              <xsl:value-of select="content:encoded" disable-output-escaping="yes"/>
            </xsl:when>
            <xsl:when test="description">
              <xsl:value-of select="description" disable-output-escaping="yes"/>
            </xsl:when>
          </xsl:choose>
        </div>
      </li>
    </ul>
  </xsl:template>

</xsl:stylesheet>
