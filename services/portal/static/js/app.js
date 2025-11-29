/**
 * Healthcare Lab Portal - Main JavaScript
 * Handles interactions, animations, and dynamic features
 */

(function() {
    'use strict';
    
    // ===================================
    // Constants
    // ===================================
    const ANIMATION_DURATION = 300;
    const DEBOUNCE_DELAY = 250;
    
    // ===================================
    // Utility Functions
    // ===================================
    
    /**
     * Debounce function to limit rate of function calls
     */
    function debounce(func, wait) {
        let timeout;
        return function executedFunction(...args) {
            const later = () => {
                clearTimeout(timeout);
                func(...args);
            };
            clearTimeout(timeout);
            timeout = setTimeout(later, wait);
        };
    }
    
    /**
     * Add animation class to element
     */
    function animateElement(element, animationClass) {
        element.classList.add(animationClass);
        setTimeout(() => {
            element.classList.remove(animationClass);
        }, ANIMATION_DURATION);
    }
    
    /**
     * Show/Hide element with animation
     */
    function toggleElement(element, show) {
        if (show) {
            element.style.display = 'block';
            setTimeout(() => element.classList.add('slide-in'), 10);
        } else {
            element.classList.remove('slide-in');
            setTimeout(() => element.style.display = 'none', ANIMATION_DURATION);
        }
    }
    
    // ===================================
    // Flash Messages Auto-dismiss
    // ===================================
    function initFlashMessages() {
        const flashMessages = document.querySelectorAll('.flash-message');
        
        flashMessages.forEach(message => {
            // Add close button
            const closeBtn = document.createElement('button');
            closeBtn.innerHTML = '<i class="fas fa-times"></i>';
            closeBtn.className = 'ml-auto text-current opacity-70 hover:opacity-100 transition';
            closeBtn.onclick = () => dismissFlashMessage(message);
            message.appendChild(closeBtn);
            
            // Auto-dismiss after 5 seconds
            setTimeout(() => dismissFlashMessage(message), 5000);
        });
    }
    
    function dismissFlashMessage(message) {
        message.style.opacity = '0';
        message.style.transform = 'translateX(100%)';
        setTimeout(() => message.remove(), ANIMATION_DURATION);
    }
    
    // ===================================
    // Search/Filter Functionality
    // ===================================
    function initSearchFilter() {
        const searchInput = document.getElementById('searchResults');
        if (!searchInput) return;
        
        const handleSearch = debounce((query) => {
            const resultCards = document.querySelectorAll('.result-card');
            const lowerQuery = query.toLowerCase();
            
            resultCards.forEach(card => {
                const text = card.textContent.toLowerCase();
                const shouldShow = text.includes(lowerQuery);
                
                if (shouldShow) {
                    card.style.display = 'block';
                    animateElement(card, 'slide-in');
                } else {
                    card.style.display = 'none';
                }
            });
            
            // Show "no results" message if nothing visible
            updateNoResultsMessage(resultCards);
        }, DEBOUNCE_DELAY);
        
        searchInput.addEventListener('input', (e) => handleSearch(e.target.value));
    }
    
    function updateNoResultsMessage(cards) {
        const visibleCards = Array.from(cards).filter(card => card.style.display !== 'none');
        let noResultsMsg = document.getElementById('noResultsMessage');
        
        if (visibleCards.length === 0) {
            if (!noResultsMsg) {
                noResultsMsg = document.createElement('div');
                noResultsMsg.id = 'noResultsMessage';
                noResultsMsg.className = 'card text-center py-8';
                noResultsMsg.innerHTML = `
                    <i class="fas fa-search text-gray-400 text-4xl mb-4"></i>
                    <p class="text-gray-600">No results found. Try a different search term.</p>
                `;
                cards[0]?.parentElement.appendChild(noResultsMsg);
            }
            toggleElement(noResultsMsg, true);
        } else if (noResultsMsg) {
            toggleElement(noResultsMsg, false);
        }
    }
    
    // ===================================
    // Tooltips
    // ===================================
    function initTooltips() {
        const tooltipElements = document.querySelectorAll('[data-tooltip]');
        
        tooltipElements.forEach(element => {
            const tooltipText = element.getAttribute('data-tooltip');
            
            element.addEventListener('mouseenter', () => {
                const tooltip = createTooltip(tooltipText);
                document.body.appendChild(tooltip);
                positionTooltip(tooltip, element);
            });
            
            element.addEventListener('mouseleave', () => {
                const tooltip = document.querySelector('.tooltip');
                if (tooltip) tooltip.remove();
            });
        });
    }
    
    function createTooltip(text) {
        const tooltip = document.createElement('div');
        tooltip.className = 'tooltip fixed bg-gray-900 text-white text-sm px-3 py-2 rounded-lg shadow-xl z-50';
        tooltip.textContent = text;
        return tooltip;
    }
    
    function positionTooltip(tooltip, element) {
        const rect = element.getBoundingClientRect();
        tooltip.style.left = `${rect.left + (rect.width / 2)}px`;
        tooltip.style.top = `${rect.top - 40}px`;
        tooltip.style.transform = 'translateX(-50%)';
    }
    
    // ===================================
    // Modal Functionality
    // ===================================
    function initModals() {
        const modalTriggers = document.querySelectorAll('[data-modal]');
        
        modalTriggers.forEach(trigger => {
            trigger.addEventListener('click', (e) => {
                e.preventDefault();
                const modalId = trigger.getAttribute('data-modal');
                openModal(modalId);
            });
        });
        
        // Close modals on backdrop click
        document.addEventListener('click', (e) => {
            if (e.target.classList.contains('modal-backdrop')) {
                closeAllModals();
            }
        });
        
        // Close on Escape key
        document.addEventListener('keydown', (e) => {
            if (e.key === 'Escape') {
                closeAllModals();
            }
        });
    }
    
    function openModal(modalId) {
        const modal = document.getElementById(modalId);
        if (!modal) return;
        
        modal.style.display = 'flex';
        setTimeout(() => modal.classList.add('modal-open'), 10);
        document.body.style.overflow = 'hidden';
    }
    
    function closeAllModals() {
        const modals = document.querySelectorAll('.modal');
        modals.forEach(modal => {
            modal.classList.remove('modal-open');
            setTimeout(() => {
                modal.style.display = 'none';
                document.body.style.overflow = '';
            }, ANIMATION_DURATION);
        });
    }
    
    // ===================================
    // Smooth Scroll
    // ===================================
    function initSmoothScroll() {
        const scrollLinks = document.querySelectorAll('a[href^="#"]');
        
        scrollLinks.forEach(link => {
            link.addEventListener('click', (e) => {
                const href = link.getAttribute('href');
                if (href === '#') return;
                
                e.preventDefault();
                const target = document.querySelector(href);
                
                if (target) {
                    target.scrollIntoView({
                        behavior: 'smooth',
                        block: 'start'
                    });
                }
            });
        });
    }
    
    // ===================================
    // Form Validation
    // ===================================
    function initFormValidation() {
        const forms = document.querySelectorAll('form[data-validate]');
        
        forms.forEach(form => {
            form.addEventListener('submit', (e) => {
                if (!validateForm(form)) {
                    e.preventDefault();
                    showFormErrors(form);
                }
            });
        });
    }
    
    function validateForm(form) {
        const requiredFields = form.querySelectorAll('[required]');
        let isValid = true;
        
        requiredFields.forEach(field => {
            if (!field.value.trim()) {
                isValid = false;
                field.classList.add('border-red-500');
            } else {
                field.classList.remove('border-red-500');
            }
        });
        
        return isValid;
    }
    
    function showFormErrors(form) {
        const errorMsg = form.querySelector('.form-error') || createFormError();
        form.insertBefore(errorMsg, form.firstChild);
        animateElement(errorMsg, 'slide-in');
    }
    
    function createFormError() {
        const error = document.createElement('div');
        error.className = 'form-error flash-error mb-4';
        error.innerHTML = '<i class="fas fa-exclamation-circle mr-2"></i>Please fill in all required fields.';
        return error;
    }
    
    // ===================================
    // Copy to Clipboard
    // ===================================
    function initCopyButtons() {
        const copyButtons = document.querySelectorAll('[data-copy]');
        
        copyButtons.forEach(button => {
            button.addEventListener('click', () => {
                const textToCopy = button.getAttribute('data-copy');
                copyToClipboard(textToCopy, button);
            });
        });
    }
    
    function copyToClipboard(text, button) {
        navigator.clipboard.writeText(text).then(() => {
            const originalHTML = button.innerHTML;
            button.innerHTML = '<i class="fas fa-check mr-2"></i>Copied!';
            button.classList.add('bg-green-500');
            
            setTimeout(() => {
                button.innerHTML = originalHTML;
                button.classList.remove('bg-green-500');
            }, 2000);
        }).catch(err => {
            console.error('Failed to copy:', err);
        });
    }
    
    // ===================================
    // Loading Indicators
    // ===================================
    function showLoading(element) {
        const spinner = document.createElement('div');
        spinner.className = 'spinner mx-auto';
        element.innerHTML = '';
        element.appendChild(spinner);
    }
    
    function hideLoading(element, content) {
        element.innerHTML = content;
    }
    
    // ===================================
    // Stats Counter Animation
    // ===================================
    function animateCounters() {
        const counters = document.querySelectorAll('.stat-value[data-count]');
        
        counters.forEach(counter => {
            const target = parseInt(counter.getAttribute('data-count'));
            const duration = 2000;
            const step = target / (duration / 16);
            let current = 0;
            
            const timer = setInterval(() => {
                current += step;
                if (current >= target) {
                    counter.textContent = target;
                    clearInterval(timer);
                } else {
                    counter.textContent = Math.floor(current);
                }
            }, 16);
        });
    }
    
    // ===================================
    // Intersection Observer for Animations
    // ===================================
    function initScrollAnimations() {
        const observerOptions = {
            threshold: 0.1,
            rootMargin: '0px 0px -100px 0px'
        };
        
        const observer = new IntersectionObserver((entries) => {
            entries.forEach(entry => {
                if (entry.isIntersecting) {
                    entry.target.classList.add('slide-in');
                    observer.unobserve(entry.target);
                }
            });
        }, observerOptions);
        
        document.querySelectorAll('.animate-on-scroll').forEach(el => {
            observer.observe(el);
        });
    }
    
    // ===================================
    // Initialize Everything
    // ===================================
    function init() {
        console.log('Healthcare Lab Portal - Initializing...');
        
        // Initialize all features
        initFlashMessages();
        initSearchFilter();
        initTooltips();
        initModals();
        initSmoothScroll();
        initFormValidation();
        initCopyButtons();
        initScrollAnimations();
        
        // Run counter animation if stats exist
        if (document.querySelector('.stat-value[data-count]')) {
            animateCounters();
        }
        
        console.log('Healthcare Lab Portal - Ready!');
    }
    
    // Wait for DOM to be ready
    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', init);
    } else {
        init();
    }
    
    // Expose utilities globally for inline scripts
    window.HealthcarePortal = {
        showLoading,
        hideLoading,
        animateElement,
        toggleElement
    };
})();