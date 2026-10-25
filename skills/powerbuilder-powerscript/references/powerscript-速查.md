# PowerScript 速查

## 文件结构

PowerBuilder 导出的源码常见结构：

```powerscript
forward
global type nvo_x from nonvisualobject
end type
end forward

global type nvo_x from nonvisualobject
end type
global nvo_x nvo_x

type variables
string is_name
end variables

forward prototypes
public function integer of_work (string as_arg, ref string as_message)
end prototypes

public function integer of_work (string as_arg, ref string as_message);
...
end function
```

## 命名习惯

- `nvo_`：非可视对象。
- `uo_`：用户对象。
- `w_`：窗口。
- `dw_` / `ds_` / `ids_`：DataWindow 或 DataStore 相关对象。
- `of_`：对象函数。
- `ue_`：用户事件。
- `is_`、`ii_`、`il_`、`ib_`：实例变量常见前缀。
- `ls_`、`li_`、`ll_`、`ld_`、`ldt_`：局部变量常见前缀。

## 函数与 ref 参数

`ref` 参数可被函数内部修改，用于返回多个结果。改造或迁移时要保留输出语义。

```powerscript
public function integer of_query (string as_id, ref string as_message);
as_message = ""
return 1
end function
```

## 事件

事件可以在 `global type` 中声明，也可以实现为 `event name; ... end event`。窗口和用户对象中大量逻辑可能挂在控件事件上。

```powerscript
event open;
inv_service = create nvo_service
end event
```

## 对象生命周期

- 创建：`obj = create nvo_x`
- 销毁：`destroy obj`
- 判空/有效：常见 `isvalid(obj)` 与项目自定义 `f_isnull(...)`
- 析构事件中应释放已创建对象。

## SQLCA 与事务

PowerScript 内嵌 SQL 后通常检查 `SQLCA.SQLCode`：

```powerscript
insert into TableA(Id, Name) values(:ls_id, :ls_name);
if sqlca.sqlcode <> 0 then
    f_trap_sqlca()
    rollback;
    return -1
end if

commit;
```

审查时关注：

- 每个失败分支是否 `rollback`。
- `commit` 是否只在所有写入成功后执行。
- 删除后重插入是否保留旧业务字段。
- `select ... into` 无记录时是否有合理默认值。

## NULL、字符串与日期

- PowerScript 的 `NULL` 传播容易影响表达式结果，不能简单等同空字符串。
- 日期/时间转换常见项目函数：`f_string2datetime(...)` 或对象内部 `__of_string2datetime(...)`。
- 旧源码可能用中文标点、`~r~n` 换行、`~t` 制表。

## 常见风险

- 文件编码被改坏，导致中文注释、字符串或 PB 导出头乱码。
- 把 `ref` 参数当普通入参处理。
- 忽略 `SQLCA.SQLCode` 的失败路径。
- 把窗口控件事件逻辑误认为普通声明块。
- 迁移时遗漏全局对象，例如 `gnv_app`、`gnv_config`、`gnv_wait`。

## 完整资料

完整手册在 `docs/reference/powerscript/manual/`。优先查速查和附录，只有复杂语义或函数细节不明时再查全文。
