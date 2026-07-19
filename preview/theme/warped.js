(function() {
  'use strict';
  
  // Default configuration - can be overridden by window.WarpedConfig
  const defaultConfig = {
    debug: true,
    brandColours: {
      STARTING_HUE: 14,        // Orange-red starting point
      MAX_HUE: 255,            // Blue-violet ending point
      SATURATION: 57,          // Saturation percentage
      LIGHTNESS: 62,           // Lightness percentage
      DEFAULT_OPACITY: 0.25,   // Default opacity (25%)
      HOVER_OPACITY: 1         // Hover opacity (100%)
    },
    selectors: "article p>a, article li>a, header p.description a",
    enableBranding: true,
    enableCodeGrams: true,     // Enable automatic code-gram detection and styling
    debounceDelay: 16          // Hover debounce delay in milliseconds (0 to disable)
  };

  // Merge user config with defaults
  const config = Object.assign({}, defaultConfig, window.WarpedConfig || {});
  const debug = config.debug;
  const BRAND_COLOURS = Object.assign({}, defaultConfig.brandColours, config.brandColours || {});
  
  /**
   * Namespace object containing all warped.js functionality for weblog theming
   * and visual enhancement. Provides rainbow link colorization and decorative
   * branding elements without external dependencies.
   * @namespace Warped
   */
  const Warped = {
    
    // Private properties using Symbol-like naming for better encapsulation
    _cache: {
      body: null,
      targetedLinks: null,
      initialized: false
    },
    
    _eventDelegationSetup: false,
    _hoverDebounceTimeout: null,
    
    /**
     * Initialize DOM element cache to avoid repeated queries
     * @private
     */
    _initCache() {
      if (this._cache.initialized) return;
      
      const { body } = document;
      const targetedLinks = document.querySelectorAll(config.selectors);
      
      // Update cache with destructured values
      Object.assign(this._cache, {
        body,
        targetedLinks,
        initialized: true
      });
      
      this._d(`Cached ${targetedLinks?.length || 0} targeted links`);
    },
    
    /**
     * Simple debounce utility for hover events
     * @private
     * @param {Function} func - Function to debounce
     * @param {number} [delay=16] - Delay in milliseconds (default 16ms for ~60fps)
     * @returns {Function} Debounced function
     */
    _debounce(func, delay = 16) {
      return (...args) => {
        clearTimeout(this._hoverDebounceTimeout);
        this._hoverDebounceTimeout = setTimeout(() => func.apply(this, args), delay);
      };
    },
    
    /**
     * Set up event delegation for hover effects on warped links
     * Uses a single event listener on document body instead of individual listeners
     * @private
     */
    _setupEventDelegation() {
      if (this._eventDelegationSetup || !this._cache.body) return;
      
      // Target selector for event delegation
      const targetSelector = config.selectors;
      
      // Create hover handlers (debounced for performance if delay > 0)
      const mouseoverHandler = (target) => {
        try {
          const hoverColor = target.getAttribute("data-hue-hover");
          const { style } = target;
          if (hoverColor && style) {
            style.borderBottomColor = hoverColor;
          }
        } catch (error) {
          this._d(`Error in mouseover handler: ${error.message}`, true);
        }
      };
      
      const mouseoutHandler = (target) => {
        try {
          const defaultColor = target.getAttribute("data-hue");
          const { style } = target;
          if (defaultColor && style) {
            style.borderBottomColor = defaultColor;
          }
        } catch (error) {
          this._d(`Error in mouseout handler: ${error.message}`, true);
        }
      };
      
      const debouncedMouseover = config.debounceDelay > 0 ? this._debounce(mouseoverHandler, config.debounceDelay) : mouseoverHandler;
      const debouncedMouseout = config.debounceDelay > 0 ? this._debounce(mouseoutHandler, config.debounceDelay) : mouseoutHandler;
      
      // Single mouseover handler for all targeted links
      this._cache.body.addEventListener("mouseover", ({ target }) => {
        if (target?.matches?.(targetSelector)) {
          debouncedMouseover(target);
        }
      });
      
      // Single mouseout handler for all targeted links
      this._cache.body.addEventListener("mouseout", ({ target }) => {
        if (target?.matches?.(targetSelector)) {
          debouncedMouseout(target);
        }
      });
      
      this._eventDelegationSetup = true;
      this._d("Event delegation with debouncing setup completed");
    },
    
    /**
     * Debug logging with conditional output based on debug flag
     * @param {string} text - Message to log to console
     * @param {boolean} [forceLog=false] - Override debug flag to force logging
     */
    _d(text, forceLog = false) {
      if (debug || forceLog) {
        console.log(text);
      }
    },

    /**
     * Add decorative brand bars to top and bottom of page
     * Creates flourish elements with horizontal lines for visual branding
     */
    warpBranding() {
      // Initialize cache if not already done
      this._initCache();
      
      // Validate that document.body exists before manipulation
      if (!this._cache.body) {
        this._d("Error: document.body not found, cannot add branding", true);
        return;
      }

      try {
        const brandBarElements = `<div class="flourish left"><hr><hr><hr><hr></div>
           <div class="flourish right"><hr><hr><hr><hr></div>`;

        const topContainer = document.createElement("div");
        if (!topContainer) {
          this._d("Error: Could not create top container element", true);
          return;
        }
        
        topContainer.innerHTML = brandBarElements;
        topContainer.classList.add("top", "warped-bar");
        
        // Check for firstChild to avoid null reference
        const { body } = this._cache;
        const { firstChild } = body;
        if (firstChild) {
          body.insertBefore(topContainer, firstChild);
        } else {
          body.appendChild(topContainer);
        }

        const bottomContainer = document.createElement("div");
        if (!bottomContainer) {
          this._d("Error: Could not create bottom container element", true);
          return;
        }
        
        bottomContainer.innerHTML = brandBarElements;
        bottomContainer.classList.add("bottom", "warped-bar");
        body.appendChild(bottomContainer);

        this._d("w40 branding added");
      } catch (error) {
        this._d(`Error adding branding: ${error.message}`, true);
      }
    },

    /**
     * Apply code-gram styling to paragraphs containing only code elements
     * Searches for <p> elements within .post-content that contain only <code> elements
     */
    warpCodeGrams() {
      // Initialize cache if not already done
      this._initCache();
      
      // Validate that document.body exists
      if (!this._cache.body) {
        this._d("Error: document.body not found, cannot process code grams", true);
        return;
      }

      try {
        // Find all paragraphs within .post-content blocks
        const postContentBlocks = document.querySelectorAll('.post-content');
        let totalCodeGrams = 0;

        postContentBlocks.forEach(contentBlock => {
          const paragraphs = contentBlock.querySelectorAll('p');
          
          paragraphs.forEach(paragraph => {
            // Check if paragraph contains only code element(s) and whitespace
            const hasOnlyCodeContent = this._isCodeOnlyParagraph(paragraph);
            
            if (hasOnlyCodeContent) {
              paragraph.classList.add('code-gram');
              totalCodeGrams++;
              this._d(`Added code-gram class to paragraph: "${paragraph.textContent.trim().substring(0, 50)}..."`);
            }
          });
        });

        this._d(`Code grams processed: ${totalCodeGrams} paragraphs marked`);
      } catch (error) {
        this._d(`Error processing code grams: ${error.message}`, true);
      }
    },

    /**
     * Check if a paragraph element contains only code elements and whitespace
     * @private
     * @param {Element} paragraph - The paragraph element to check
     * @returns {boolean} True if paragraph contains only code elements
     */
    _isCodeOnlyParagraph(paragraph) {
      if (!paragraph || !paragraph.childNodes) {
        return false;
      }

      let hasCodeElement = false;
      
      // Check each child node
      for (const node of paragraph.childNodes) {
        if (node.nodeType === Node.ELEMENT_NODE) {
          // If it's an element, it must be a <code> element
          if (node.tagName.toLowerCase() === 'code') {
            hasCodeElement = true;
          } else {
            // Any non-code element disqualifies it
            return false;
          }
        } else if (node.nodeType === Node.TEXT_NODE) {
          // Text nodes must be empty or only whitespace
          if (node.textContent.trim() !== '') {
            return false;
          }
        }
        // Ignore other node types (comments, etc.)
      }
      
      return hasCodeElement;
    },

    /**
     * Apply rainbow gradient colors to a collection of links with hover effects
     * Distributes HSL colors evenly across all provided links
     * @param {NodeList|Array} links - Collection of anchor elements to colorize
     * @example
     * Warped.warpRainbowLinks(document.querySelectorAll('article a'));
     */
    warpRainbowLinks(links) {
      // Validate links parameter
      if (!links) {
        this._d("Error: links parameter is null or undefined", true);
        return;
      }

      if (!links.length && links.length !== 0) {
        this._d("Error: links parameter is not array-like (missing length property)", true);
        return;
      }

      const totalLinks = links.length;
      if (totalLinks === 0) {
        this._d("No links found");
        return;
      }

      try {
        const { STARTING_HUE, MAX_HUE, SATURATION, LIGHTNESS, DEFAULT_OPACITY, HOVER_OPACITY } = BRAND_COLOURS;
        let hue = STARTING_HUE;
        // Calculate even distribution of colors across all links
        const increment = Math.round((MAX_HUE - STARTING_HUE) / totalLinks);

        links.forEach((link, index) => {
          // Validate each link element
          if (!link || !link.nodeType || link.nodeType !== Node.ELEMENT_NODE) {
            this._d(`Warning: Skipping invalid link at index ${index}`, true);
            return;
          }

          try {
            // Generate HSL colors using configuration constants
            const hslaColorDefault = `hsla(${hue}, ${SATURATION}%, ${LIGHTNESS}%, ${DEFAULT_OPACITY})`;
            const hslaColorHover = `hsla(${hue}, ${SATURATION}%, ${LIGHTNESS}%, ${HOVER_OPACITY})`;

            // Store colors as data attributes for hover event handlers
            link.setAttribute("data-hue", hslaColorDefault);
            link.setAttribute("data-hue-hover", hslaColorHover);

            // Apply default color to bottom border
            if (link.style) {
              link.style.borderBottomColor = hslaColorDefault;
            }

          } catch (error) {
            this._d(`Error processing link at index ${index}: ${error.message}`, true);
          }

          // Advance to next color, wrapping back to start if needed
          hue += increment;
          if (hue > MAX_HUE) {
            hue = STARTING_HUE;
          }
        });
      } catch (error) {
        this._d(`Error in warpRainbowLinks: ${error.message}`, true);
      }
    },

    /**
     * Initialize the warped theme system
     * Automatically applies rainbow colors to targeted links and adds branding
     */
    init() {
      try {
        this._d("w40 theme starting");

        // Validate document exists
        if (!document) {
          this._d("Error: document not available", true);
          return;
        }

        // Initialize cache for performance
        this._initCache();
        
        // Set up event delegation for hover effects
        this._setupEventDelegation();

        // Apply rainbow colors to cached targeted links
        if (this._cache.targetedLinks && this._cache.targetedLinks.length > 0) {
          this.warpRainbowLinks(this._cache.targetedLinks);
        } else {
          this._d("Warning: No targeted links found in cache", true);
        }

        // Add decorative brand flourishes if enabled
        if (config.enableBranding) {
          this.warpBranding();
        }

        // Process code grams if enabled
        if (config.enableCodeGrams) {
          this.warpCodeGrams();
        }

        this._d("w40 theme installed");
      } catch (error) {
        this._d(`Error initializing warped theme: ${error.message}`, true);
      }
    }
  };

  // Auto-initialize when DOM is ready using modern async patterns
  const initialize = () => {
    try {
      if (document?.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', () => Warped.init());
      } else if (document) {
        Warped.init();
      }
    } catch (error) {
      console.error(`Error in warped.js auto-initialization: ${error.message}`);
    }
  };
  
  initialize();
})();
