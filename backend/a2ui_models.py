from pydantic import BaseModel, Field
from typing import List, Optional, Union, Literal, Dict, Any

# --- Base Components ---

class A2UIComponent(BaseModel):
    id: Optional[str] = None
    type: str

class Text(A2UIComponent):
    type: Literal["text"] = "text"
    content: str
    variant: Literal["h1", "h2", "h3", "body", "caption", "label"] = "body"
    color: Optional[str] = None

class Image(A2UIComponent):
    type: Literal["image"] = "image"
    src: str
    alt: str
    width: Optional[str] = None
    height: Optional[str] = None

class Button(A2UIComponent):
    type: Literal["button"] = "button"
    label: str
    action_id: str
    variant: Literal["primary", "secondary", "outline", "ghost"] = "primary"
    payload: Optional[Dict[str, Any]] = None

class Box(A2UIComponent):
    type: Literal["box"] = "box"
    children: List[Union["Text", "Image", "Button", "Box", "Card", "List"]] = []
    direction: Literal["row", "column"] = "column"
    gap: Optional[str] = None
    padding: Optional[str] = None
    alignment: Literal["start", "center", "end", "stretch"] = "start"

# --- Composite Components ---

class Card(A2UIComponent):
    type: Literal["card"] = "card"
    title: Optional[str] = None
    subtitle: Optional[str] = None
    image: Optional[Image] = None
    content: List[Union[Text, Box]] = []
    actions: List[Button] = []

class ListComponent(A2UIComponent):
    type: Literal["list"] = "list"
    items: List[Card]
    orientation: Literal["vertical", "horizontal", "grid"] = "vertical"

# --- Root Message ---

class A2UIMessage(BaseModel):
    """
    Top-level container for an A2UI message.
    """
    type: Literal["a2ui"] = "a2ui"
    root: Union[Box, Card, ListComponent, Text]

# Update forward references for recursive Box definition
Box.update_forward_refs()
