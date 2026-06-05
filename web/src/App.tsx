import React, { useEffect } from 'react'
import { debugData } from '@/hook'
import { isEnvBrowser } from '@/utils'
import { ContextMenu } from '@/features'
import './index.css'

const BROWSER = isEnvBrowser()

const App: React.FC = () => {
  useEffect(() => {
    if (!BROWSER) return
    debugData([
      {
        action: 'nui:context-menu:setData',
        data: [
          { id: 0, name: 'Player', icon: 'fa-solid fa-user', header: true },
          { id: 1, name: 'Profile', icon: 'fa-solid fa-id-card', description: 'View the targeted player profile.' },
          { id: 2, name: 'Inventory', icon: 'fa-solid fa-bag-shopping', style: { color: [59, 186, 130] }, description: 'Open the player inventory.' },
          { id: 3, name: 'Server ID', icon: 'fa-solid fa-hashtag', value: '12345', description: 'Click to copy the server ID.' },
          { id: -1, separator: true },
          { id: 4, name: 'Show names', icon: 'fa-solid fa-eye', checkable: true, checked: false, description: 'Display names above players.' },
          { id: 5, name: 'Show vehicles', icon: 'fa-solid fa-car', checkable: true, checked: true, description: 'Display info about nearby vehicles.' },
          { id: -2, separator: true },
          {
            id: 6, name: 'Tools', icon: 'fa-solid fa-bug', style: { color: [234, 179, 8] }, description: 'Advanced tools.',
            child: [
              { id: 7, name: 'Tools', icon: 'fa-solid fa-gear', header: true },
              { id: 8, name: 'Coordinates', icon: 'fa-solid fa-location-dot', checkable: true, checked: true },
              { id: 9, name: 'Outlines', icon: 'fa-solid fa-vector-square', checkable: true, checked: false },
              { id: 10, name: 'Entity IDs', icon: 'fa-solid fa-hashtag', checkable: true, checked: false },
            ],
          },
          { id: 11, name: 'Close', icon: 'fa-solid fa-xmark', style: { color: [239, 68, 68] }, description: 'Close the context menu.' },
        ],
      },
    ], 0)
    debugData([{ action: 'nui:context-menu:visible', data: true }], 50)
  }, [])

  return <ContextMenu />
}

export default App
