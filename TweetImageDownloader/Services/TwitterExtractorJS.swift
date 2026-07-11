import Foundation

/// 封装用于在 WKWebView 中执行推文解析的 JavaScript 核心引擎
public enum TwitterExtractorJS {
    
    /// 获取执行在 WKWebView 中抓取目标作者推文原图及预览图的 JS 代码
    public static var extractionScript: String {
        return """
        (function() {
            try {
                // 1. 从当前 URL 提取目标作者用户名 (例如: https://x.com/limboprossr/status/12345)
                var pathParts = window.location.pathname.split('/').filter(Boolean);
                var targetUsername = "";
                if (pathParts.length >= 1) {
                    targetUsername = pathParts[0].toLowerCase();
                }
                
                // 2. 遍历推文容器，过滤属于目标作者的主推文和作者评论区连贴
                var allCards = document.querySelectorAll('[data-testid="cellInnerDiv"]');
                var extractedImages = [];
                var seenUrls = new Set();
                
                function cleanImageUrl(url) {
                    return url.replace(/&?name=[^&]+/ig, '');
                }
                
                function isAuthorCard(card, username) {
                    if (!username) return true;
                    var links = card.querySelectorAll('a[href*="/status/"]');
                    for (var i = 0; i < links.length; i++) {
                        var href = links[i].getAttribute('href') || "";
                        if (href.toLowerCase().indexOf('/' + username + '/status/') !== -1) {
                            return true;
                        }
                    }
                    // 额外检查账号名字展示区
                    var userLinks = card.querySelectorAll('a[role="link"]');
                    for (var j = 0; j < userLinks.length; j++) {
                        var text = userLinks[j].textContent || "";
                        if (text.toLowerCase() === '@' + username) {
                            return true;
                        }
                    }
                    return false;
                }

                // 遍历卡片
                for (var i = 0; i < allCards.length; i++) {
                    var card = allCards[i];
                    
                    // 判断该推文卡片是否为目标作者发帖或连帖
                    if (targetUsername && !isAuthorCard(card, targetUsername)) {
                        continue;
                    }
                    
                    // 抓取该推文卡片内所有配图 (排除头像与 Emoji)
                    var imgs = card.querySelectorAll("img[src*='twimg.com/media/'], img[src*='name=']");
                    for (var k = 0; k < imgs.length; k++) {
                        var img = imgs[k];
                        var src = img.src || "";
                        
                        // 过滤头像、系统图标与非推文配图
                        if (src.indexOf('profile_images') !== -1 || src.indexOf('emoji') !== -1 || src.indexOf('twimg.com/media/') === -1) {
                            continue;
                        }
                        
                        var baseUrl = cleanImageUrl(src);
                        if (seenUrls.has(baseUrl)) {
                            continue;
                        }
                        seenUrls.add(baseUrl);
                        
                        // 构造中等清晰度预览图与原始最高分辨率 (name=orig) 原图 URL
                        var previewURL = baseUrl + (baseUrl.indexOf('?') !== -1 ? '&name=medium' : '?name=medium');
                        var originalURL = baseUrl + (baseUrl.indexOf('?') !== -1 ? '&name=orig' : '?name=orig');
                        
                        extractedImages.push({
                            "previewURL": previewURL,
                            "originalURL": originalURL,
                            "authorUsername": targetUsername || "unknown"
                        });
                    }
                }
                
                return JSON.stringify({
                    "success": true,
                    "author": targetUsername,
                    "count": extractedImages.length,
                    "images": extractedImages
                });
            } catch (err) {
                return JSON.stringify({
                    "success": false,
                    "error": err.toString()
                });
            }
        })();
        """
    }
}
