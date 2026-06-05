import "./style.scss";
import React, { useEffect, useState, useRef, useCallback } from "react";
import { useNuiEvent } from "@/hook/nuiEvent";
import { fetchNui } from "@/hook/fetchNui";
import { isEnvBrowser } from "@/utils/misc";
import { setClipboard } from "@/utils/clipboard";

interface MenuItem {
  id: number;
  name?: string;
  icon?: string;
  value?: string;
  description?: string;
  header?: boolean;
  separator?: boolean;
  checked?: boolean;
  checkable?: boolean;
  disabled?: boolean;
  style?: { color?: [number, number, number] };
  child?: MenuItem[];
}

function safeParseItems(items: unknown): MenuItem[] {
  if (Array.isArray(items)) return items;
  if (typeof items === "string") {
    try { const p = JSON.parse(items); return Array.isArray(p) ? p : []; }
    catch { return []; }
  }
  return [];
}

const ITEMS_PER_PAGE = 9;

const ContextMenu: React.FC = () => {
  const [visible, setVisible] = useState(false);
  const [menuData, setMenuData] = useState<MenuItem[]>([]);
  const [position, setPosition] = useState({ x: 0, y: 0 });
  const [checkedMap, setCheckedMap] = useState<Record<number, boolean>>({});
  const [currentPage, setCurrentPage] = useState(0);
  const [hoveredDesc, setHoveredDesc] = useState<string | null>(null);
  const mockDataRef = useRef<MenuItem[]>([]);
  const anchorRef = useRef<HTMLDivElement>(null);
  const BROWSER = isEnvBrowser();

  const reset = () => {
    setMenuData([]);
    setCurrentPage(0);
    setHoveredDesc(null);
  };

  useNuiEvent<boolean>("nui:context-menu:visible", (status) => {
    setVisible(status);
    if (!status) { reset(); mockDataRef.current = []; }
  });

  useNuiEvent<MenuItem[]>("nui:context-menu:setData", (data) => {
    mockDataRef.current = safeParseItems(data);
  });

  const handleRightClick = useCallback(async (e: MouseEvent) => {
    if (!visible) return;
    e.preventDefault();

    let items: MenuItem[];
    if (BROWSER) {
      items = mockDataRef.current;
    } else {
      const raw = await fetchNui<MenuItem[] | string>("ContextMenuPosition", { x: e.clientX, y: e.clientY });
      items = safeParseItems(raw);
    }

    if (!items.length) return;

    const init: Record<number, boolean> = {};
    const initChecked = (list: MenuItem[]) => {
      list.forEach(item => {
        if (item.checkable) init[item.id] = item.checked ?? false;
        if (item.child) initChecked(item.child);
      });
    };
    initChecked(items);
    setCheckedMap(init);
    setMenuData(items);
    setCurrentPage(0);

    // Placement initial au curseur ; la position est corrigée après mesure
    // de la taille réelle du menu (voir useEffect ci-dessous).
    setPosition({ x: e.clientX, y: e.clientY });
  }, [visible, BROWSER]);

  // Une fois le menu rendu, on mesure sa taille réelle et on le repositionne
  // pour qu'il reste entièrement visible dans la fenêtre.
  useEffect(() => {
    if (!menuData.length) return;
    const el = anchorRef.current;
    if (!el) return;

    const { width, height } = el.getBoundingClientRect();
    const W = window.innerWidth, H = window.innerHeight;
    const margin = 8;

    setPosition(prev => {
      let x = prev.x, y = prev.y;
      if (x + width + margin > W) x = W - width - margin;
      if (y + height + margin > H) y = H - height - margin;
      if (x < margin) x = margin;
      if (y < margin) y = margin;
      return x === prev.x && y === prev.y ? prev : { x, y };
    });
  }, [menuData, currentPage]);

  const handleClickOutside = useCallback(() => {
    if (visible && menuData.length > 0) {
      reset();
      if (!BROWSER) fetchNui("ContextMenuClose");
    }
  }, [visible, menuData, BROWSER]);

  useEffect(() => {
    window.addEventListener("contextmenu", handleRightClick);
    window.addEventListener("click", handleClickOutside);
    return () => {
      window.removeEventListener("contextmenu", handleRightClick);
      window.removeEventListener("click", handleClickOutside);
    };
  }, [handleRightClick, handleClickOutside]);

  const handleItemClick = (item: MenuItem, e: React.MouseEvent) => {
    if (item.header || item.separator || item.disabled || item.child) return;
    e.stopPropagation();

    if (item.checkable) {
      const next = !checkedMap[item.id];
      setCheckedMap(prev => ({ ...prev, [item.id]: next }));
      if (!BROWSER) fetchNui("ContextMenuCheckToggle", { id: item.id, checked: next });
      return;
    }

    if (item.value) { setClipboard(item.value); return; }

    if (!BROWSER) fetchNui("ContextMenuButtonClick", { id: item.id });
    reset();
  };

  const renderMenu = (items: MenuItem[], depth = 0): React.ReactNode => {
    const safe = safeParseItems(items);
    if (!safe.length) return null;

    const header = safe.find(i => i.header);
    const body = safe.filter(i => !i.header);

    const nonSep = body.filter(i => !i.separator);
    const totalPages = depth === 0 ? Math.ceil(nonSep.length / ITEMS_PER_PAGE) : 1;
    const page = depth === 0 ? currentPage : 0;

    let nonSepIdx = 0;
    const paged = depth === 0 && totalPages > 1
      ? body.filter(i => {
          if (i.separator) return true;
          const idx = nonSepIdx++;
          return idx >= page * ITEMS_PER_PAGE && idx < (page + 1) * ITEMS_PER_PAGE;
        })
      : body;

    return (
      <ul className="ctx-list">
        {header && (
          <li className="ctx-header">
            {header.icon && <i className={header.icon} />}
            <span>{header.name}</span>
          </li>
        )}

        {paged.map((item, idx) => {
          if (item.separator) return <li key={`sep-${idx}`} className="ctx-sep" />;

          const rgb = item.style?.color;
          const accent = rgb ? `rgb(${rgb[0]},${rgb[1]},${rgb[2]})` : undefined;
          const isChecked = checkedMap[item.id] ?? false;

          return (
            <li
              key={item.id}
              className={`ctx-item${item.child ? " ctx-has-child" : ""}${item.disabled ? " ctx-disabled" : ""}`}
              style={accent ? { "--accent": accent } as React.CSSProperties : {}}
              onClick={e => handleItemClick(item, e)}
              onMouseEnter={() => setHoveredDesc(item.description ?? null)}
              onMouseLeave={() => setHoveredDesc(null)}
            >
              <span className="ctx-icon">{item.icon && <i className={item.icon} />}</span>
              <span className="ctx-label">{item.name}</span>

              {item.value && <span className="ctx-badge">{item.value}</span>}

              {item.checkable && (
                <span className={`ctx-check${isChecked ? " is-checked" : ""}`}>
                  {isChecked && <i className="fa-solid fa-check" />}
                </span>
              )}

              {item.child && (
                <span className="ctx-arrow"><i className="fa-solid fa-chevron-right" /></span>
              )}

              {item.child && (
                <div className="ctx-submenu">
                  {renderMenu(item.child, depth + 1)}
                </div>
              )}
            </li>
          );
        })}

        {depth === 0 && totalPages > 1 && (
          <li className="ctx-pages">
            <button className="ctx-pgbtn" disabled={page === 0}
              onClick={e => { e.stopPropagation(); setCurrentPage(p => p - 1); }}>
              <i className="fa-solid fa-chevron-left" />
            </button>
            <span>{page + 1} / {totalPages}</span>
            <button className="ctx-pgbtn" disabled={page >= totalPages - 1}
              onClick={e => { e.stopPropagation(); setCurrentPage(p => p + 1); }}>
              <i className="fa-solid fa-chevron-right" />
            </button>
          </li>
        )}
      </ul>
    );
  };

  if (!visible) return null;

  return (
    <div className="ctx-root">
      {menuData.length > 0 && (
        <div ref={anchorRef} className="ctx-anchor" style={{ top: position.y, left: position.x }}>
          {renderMenu(menuData)}
          {hoveredDesc && (
            <div className="ctx-desc">
              <i className="fa-solid fa-circle-info" />
              <span>{hoveredDesc}</span>
            </div>
          )}
        </div>
      )}
    </div>
  );
};

export default ContextMenu;