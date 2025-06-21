# frozen_string_literal: true

class OrganizationStructure < ApplicationRecord
  has_many :organization_nodes, dependent: :destroy
  has_many :organization_changes, dependent: :destroy
  
  # 組織圖狀態
  STATUS_OPTIONS = {
    'active' => '使用中',
    'draft' => '草稿',
    'archived' => '已封存',
    'historical' => '歷史版本'
  }.freeze
  
  validates :name, presence: true
  validates :effective_date, presence: true
  validates :status, presence: true, inclusion: { in: STATUS_OPTIONS.keys }
  validates :version, presence: true, uniqueness: { scope: :effective_date }
  
  scope :active, -> { where(status: 'active') }
  scope :by_date, ->(date) { where('effective_date <= ?', date).order(:effective_date) }
  scope :current, -> { where(status: 'active').order(:effective_date).last }
  scope :historical, -> { where(status: 'historical').order(:effective_date) }
  
  # 允許Ransack搜尋的屬性
  def self.ransackable_attributes(auth_object = nil)
    %w[name effective_date status version description created_at updated_at]
  end
  
  def self.ransackable_associations(auth_object = nil)
    %w[organization_nodes organization_changes]
  end
  
  # 取得狀態中文名稱
  def status_name
    STATUS_OPTIONS[status]
  end
  
  # 檢查是否為目前使用的組織圖
  def current?
    status == 'active'
  end
  
  # 取得根節點
  def root_nodes
    organization_nodes.where(parent_id: nil).order(:sort_order)
  end
  
  # 建立組織節點
  def create_node(node_data)
    organization_nodes.create!(node_data)
  end
  
  # 複製組織結構
  def duplicate(new_effective_date, new_name = nil)
    new_structure = self.class.create!(
      name: new_name || "#{name} (#{new_effective_date})",
      effective_date: new_effective_date,
      status: 'draft',
      version: generate_next_version,
      description: "基於 #{name} 複製"
    )
    
    # 複製所有節點
    node_mapping = {}
    
    organization_nodes.order(:id).each do |node|
      new_node = new_structure.organization_nodes.create!(
        name: node.name,
        node_type: node.node_type,
        position_title: node.position_title,
        employee_id: node.employee_id,
        parent_id: nil, # 先設為nil，稍後更新
        sort_order: node.sort_order,
        description: node.description,
        is_active: node.is_active
      )
      
      node_mapping[node.id] = new_node.id
    end
    
    # 更新父子關係
    organization_nodes.where.not(parent_id: nil).each do |node|
      new_node_id = node_mapping[node.id]
      new_parent_id = node_mapping[node.parent_id]
      
      if new_node_id && new_parent_id
        new_structure.organization_nodes.find(new_node_id).update!(parent_id: new_parent_id)
      end
    end
    
    new_structure
  end
  
  # 啟用組織圖
  def activate!
    transaction do
      # 將目前的組織圖設為歷史版本
      self.class.where(status: 'active').update_all(status: 'historical')
      
      # 啟用此組織圖
      update!(status: 'active')
      
      # 記錄變更
      record_activation_change
    end
  end
  
  # 封存組織圖
  def archive!
    update!(status: 'archived')
  end
  
  # 比較與另一個組織圖的差異
  def compare_with(other_structure)
    changes = {
      added_nodes: [],
      removed_nodes: [],
      modified_nodes: [],
      moved_nodes: []
    }
    
    current_nodes = organization_nodes.index_by(&:id)
    other_nodes = other_structure.organization_nodes.index_by(&:id)
    
    # 找出新增的節點
    other_nodes.each do |id, node|
      unless current_nodes.key?(id)
        changes[:added_nodes] << node
      end
    end
    
    # 找出移除的節點
    current_nodes.each do |id, node|
      unless other_nodes.key?(id)
        changes[:removed_nodes] << node
      end
    end
    
    # 找出修改和移動的節點
    current_nodes.each do |id, current_node|
      other_node = other_nodes[id]
      next unless other_node
      
      if current_node.parent_id != other_node.parent_id
        changes[:moved_nodes] << {
          node: current_node,
          old_parent_id: current_node.parent_id,
          new_parent_id: other_node.parent_id
        }
      end
      
      if node_attributes_changed?(current_node, other_node)
        changes[:modified_nodes] << {
          node: current_node,
          changes: detect_node_changes(current_node, other_node)
        }
      end
    end
    
    changes
  end
  
  # 產生組織圖JSON資料（用於前端顯示）
  def to_chart_json
    {
      id: id,
      name: name,
      effective_date: effective_date,
      status: status,
      nodes: build_tree_structure
    }
  end
  
  # 匯出組織圖
  def export_to_csv
    require 'csv'
    
    CSV.generate(headers: true) do |csv|
      csv << ['節點ID', '節點名稱', '節點類型', '職位', '員工姓名', '員工編號', '上級節點', '排序', '描述']
      
      organization_nodes.includes(:employee, :parent).order(:sort_order).each do |node|
        csv << [
          node.id,
          node.name,
          node.node_type_name,
          node.position_title,
          node.employee&.display_name,
          node.employee&.employee_number,
          node.parent&.name,
          node.sort_order,
          node.description
        ]
      end
    end
  end
  
  # 取得組織變更歷史
  def change_history
    organization_changes.includes(:changed_by).order(:created_at)
  end
  
  # 統計資料
  def statistics
    {
      total_nodes: organization_nodes.count,
      active_nodes: organization_nodes.where(is_active: true).count,
      departments: organization_nodes.where(node_type: 'department').count,
      positions: organization_nodes.where(node_type: 'position').count,
      employees_assigned: organization_nodes.where.not(employee_id: nil).count,
      max_depth: calculate_max_depth
    }
  end
  
  # 驗證組織結構完整性
  def validate_structure
    errors = []
    
    # 檢查是否有循環引用
    if has_circular_reference?
      errors << '組織結構存在循環引用'
    end
    
    # 檢查是否有孤立節點
    orphaned_nodes = find_orphaned_nodes
    if orphaned_nodes.any?
      errors << "發現 #{orphaned_nodes.count} 個孤立節點"
    end
    
    # 檢查員工是否重複分配
    duplicate_assignments = find_duplicate_employee_assignments
    if duplicate_assignments.any?
      errors << "發現 #{duplicate_assignments.count} 個重複的員工分配"
    end
    
    errors
  end
  
  private
  
  def generate_next_version
    max_version = self.class.maximum(:version) || 0
    max_version + 1
  end
  
  def record_activation_change
    organization_changes.create!(
      change_type: 'activation',
      description: "組織圖 #{name} 已啟用",
      changed_by: nil, # 可以加入當前用戶
      changed_at: Time.current
    )
  end
  
  def node_attributes_changed?(node1, node2)
    %w[name node_type position_title employee_id description].any? do |attr|
      node1.send(attr) != node2.send(attr)
    end
  end
  
  def detect_node_changes(current_node, other_node)
    changes = {}
    
    %w[name node_type position_title employee_id description].each do |attr|
      current_value = current_node.send(attr)
      other_value = other_node.send(attr)
      
      if current_value != other_value
        changes[attr] = {
          from: current_value,
          to: other_value
        }
      end
    end
    
    changes
  end
  
  def build_tree_structure
    nodes_hash = organization_nodes.includes(:employee, :children).index_by(&:id)
    
    root_nodes.map do |root|
      build_node_tree(root, nodes_hash)
    end
  end
  
  def build_node_tree(node, nodes_hash)
    {
      id: node.id,
      name: node.name,
      type: node.node_type,
      position: node.position_title,
      employee: node.employee ? {
        id: node.employee.id,
        name: node.employee.display_name,
        employee_number: node.employee.employee_number
      } : nil,
      children: node.children.order(:sort_order).map do |child|
        build_node_tree(child, nodes_hash)
      end
    }
  end
  
  def calculate_max_depth
    return 0 if organization_nodes.empty?
    
    max_depth = 0
    
    root_nodes.each do |root|
      depth = calculate_node_depth(root, 1)
      max_depth = [max_depth, depth].max
    end
    
    max_depth
  end
  
  def calculate_node_depth(node, current_depth)
    return current_depth if node.children.empty?
    
    max_child_depth = current_depth
    
    node.children.each do |child|
      child_depth = calculate_node_depth(child, current_depth + 1)
      max_child_depth = [max_child_depth, child_depth].max
    end
    
    max_child_depth
  end
  
  def has_circular_reference?
    visited = Set.new
    
    organization_nodes.each do |node|
      next if visited.include?(node.id)
      
      if detect_cycle(node, Set.new, visited)
        return true
      end
    end
    
    false
  end
  
  def detect_cycle(node, path, visited)
    return true if path.include?(node.id)
    
    path.add(node.id)
    visited.add(node.id)
    
    if node.parent_id && !visited.include?(node.parent_id)
      parent = organization_nodes.find_by(id: node.parent_id)
      if parent && detect_cycle(parent, path.dup, visited)
        return true
      end
    end
    
    false
  end
  
  def find_orphaned_nodes
    # 找出沒有父節點但不是根節點的節點
    organization_nodes.where.not(parent_id: nil)
                     .where.not(parent_id: organization_nodes.select(:id))
  end
  
  def find_duplicate_employee_assignments
    # 找出重複分配的員工
    organization_nodes.where.not(employee_id: nil)
                     .group(:employee_id)
                     .having('COUNT(*) > 1')
                     .pluck(:employee_id)
  end
end
