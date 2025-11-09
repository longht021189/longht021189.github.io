import { For, Show, createResource, createSignal, onCleanup } from 'solid-js';
import './App.css';

type TechCollectionResponse = {
  generatedAt: string;
  files: string[];
};

type TechCollectionItem = {
  path: string;
  url: string;
  alt: string;
};

const DATA_URL =
  'https://raw.githubusercontent.com/longht021189/longht021189.github.io/refs/heads/data/tech-collection.json';

const prettifyAlt = (filePath: string) => {
  const filename = filePath.split('/').pop() ?? filePath;
  const withoutExtension = filename.replace(/\.[^.]+$/, '');
  return withoutExtension.replace(/[-_]+/g, ' ');
};

const buildImageUrl = (path: string) => {
  const base = DATA_URL.slice(0, DATA_URL.lastIndexOf('/') + 1);
  return `${base}${path}`;
};

const fetchTechCollection = async (): Promise<{
  generatedAt: string;
  items: TechCollectionItem[];
}> => {
  const response = await fetch(DATA_URL);
  if (!response.ok) {
    throw new Error('Unable to load tech collection.');
  }

  const data: TechCollectionResponse = await response.json();
  const files = Array.isArray(data.files) ? data.files : [];

  return {
    generatedAt: data.generatedAt,
    items: files.map((path) => ({
      path,
      url: buildImageUrl(path),
      alt: prettifyAlt(path),
    })),
  };
};

const App = () => {
  const [collection] = createResource(fetchTechCollection);
  const [activeItem, setActiveItem] = createSignal<TechCollectionItem | null>(null);
  const [viewerLoading, setViewerLoading] = createSignal(false);

  const openViewer = (item: TechCollectionItem) => {
    setViewerLoading(true);
    setActiveItem(item);
  };

  const closeViewer = () => {
    setActiveItem(null);
    setViewerLoading(false);
  };

  if (typeof window !== 'undefined') {
    const handleKeyDown = (event: KeyboardEvent) => {
      if (event.key === 'Escape') {
        closeViewer();
      }
    };
    window.addEventListener('keydown', handleKeyDown);
    onCleanup(() => window.removeEventListener('keydown', handleKeyDown));
  }

  return (
    <main class="page">
      <section aria-live="polite" class="gallery-section">
        <Show when={collection.loading}>
          <p class="status">Loading images…</p>
        </Show>

        <Show when={collection.error}>
          {(error) => <p class="status error">{error().message}</p>}
        </Show>

        <Show when={collection()}>
          {(data) => (
            <div class="gallery" role="list">
              <For each={data().items}>
                {(item) => (
                  <figure
                    class="tile"
                    role="listitem"
                    onClick={() => openViewer(item)}
                    tabIndex={0}
                    onKeyDown={(event) => {
                      if (event.key === 'Enter' || event.key === ' ') {
                        event.preventDefault();
                        openViewer(item);
                      }
                    }}
                  >
                    <img src={item.url} alt={item.alt} loading="lazy" decoding="async" />
                  </figure>
                )}
              </For>
            </div>
          )}
        </Show>
      </section>

      <Show when={activeItem()}>
        {(item) => (
          <div
            class="lightbox"
            role="dialog"
            aria-modal="true"
            aria-label={`Viewing ${item().alt}`}
            onClick={closeViewer}
          >
            <div
              class="lightbox__content"
              onClick={(event) => {
                event.stopPropagation();
              }}
            >
              <button
                class="lightbox__close"
                type="button"
                aria-label="Close image viewer"
                onClick={closeViewer}
              >
                ×
              </button>
              <Show when={viewerLoading()}>
                <div class="lightbox__spinner">Loading…</div>
              </Show>
              <img
                classList={{
                  'lightbox__image': true,
                  'lightbox__image--visible': !viewerLoading(),
                }}
                src={item().url}
                alt={item().alt}
                onLoad={() => setViewerLoading(false)}
                onError={() => setViewerLoading(false)}
              />
            </div>
          </div>
        )}
      </Show>
    </main>
  );
};

export default App;
